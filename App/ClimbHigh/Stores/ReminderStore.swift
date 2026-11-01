import ClimbHighCore
import Foundation
import Observation
import SwiftData

/// The only place reminders are created, changed, completed or deleted.
///
/// Screens READ reminders with SwiftData's `@Query` (so lists update live) and
/// WRITE through this store, which saves and then re-plans every alert.
/// That rule means alarms and notifications can never drift out of sync.
@MainActor
@Observable
final class ReminderStore {
    private let context: ModelContext
    private let scheduler: ReminderAlertScheduler
    private let notifications: NotificationService
    let calendar: Calendar

    init(context: ModelContext, scheduler: ReminderAlertScheduler, notifications: NotificationService, calendar: Calendar = .current) {
        self.context = context
        self.scheduler = scheduler
        self.notifications = notifications
        self.calendar = calendar
    }

    // MARK: Reading

    func all() -> [Reminder] {
        (try? context.fetch(FetchDescriptor<Reminder>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    func reminder(id: UUID) -> Reminder? {
        var descriptor = FetchDescriptor<Reminder>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// A reminder paired with where it sits in the list right now.
    struct AgendaItem: Identifiable {
        let reminder: Reminder
        let entry: AgendaEntry
        var id: UUID { reminder.id }
    }

    /// Reminders grouped for display (Overdue / Today / Upcoming / Done), soonest first.
    func agenda(now: Date = .now) -> [AgendaItem] {
        let reminders = all()
        let byID = Dictionary(uniqueKeysWithValues: reminders.map { ($0.id, $0) })
        return ReminderAgenda(calendar: calendar)
            .entries(for: reminders.map(\.snapshot), now: now)
            .compactMap { entry in byID[entry.reminderID].map { AgendaItem(reminder: $0, entry: entry) } }
    }

    func nextOccurrence(of reminder: Reminder, now: Date = .now) -> Date? {
        ReminderAgenda(calendar: calendar).nextOpenOccurrence(of: reminder.snapshot, now: now)
    }

    // MARK: Writing

    @discardableResult
    func create(title: String, details: String = "", schedule: ReminderSchedule) -> Reminder {
        let reminder = Reminder(title: Self.cleaned(title), details: details, schedule: schedule)
        context.insert(reminder)
        commit()
        Task { await notifications.requestAuthorization() }
        return reminder
    }

    func update(_ reminder: Reminder, title: String, details: String, schedule: ReminderSchedule) {
        reminder.title = Self.cleaned(title)
        reminder.details = details
        reminder.schedule = schedule
        // A changed date/repeat makes old "done" marks meaningless.
        reminder.completedOccurrences = []
        reminder.isArchived = false
        commit()
    }

    /// Marks the current occurrence done. One-time reminders move to "Done";
    /// repeating ones move on to their next date.
    func markDone(_ reminder: Reminder, occurrence: Date? = nil) {
        guard let occurrence = occurrence ?? nextOccurrence(of: reminder) else { return }
        if reminder.schedule.repeatRule.isRepeating {
            var done = reminder.completedOccurrences
            done.insert(ReminderSchedule.wholeMinute(occurrence))
            // Keep the list small: forget marks older than 90 days.
            let cutoff = Date.now.addingTimeInterval(-90 * 86_400)
            reminder.completedOccurrences = done.filter { $0 > cutoff }
        } else {
            reminder.isArchived = true
        }
        commit()
        Task { await notifications.clearDelivered(for: reminder.id) }
    }

    func markDone(reminderID: UUID, occurrence: Date?) {
        guard let reminder = reminder(id: reminderID) else { return }
        markDone(reminder, occurrence: occurrence)
    }

    /// Brings a finished reminder back.
    func reopen(_ reminder: Reminder) {
        reminder.isArchived = false
        reminder.completedOccurrences = []
        commit()
    }

    func snooze(reminderID: UUID, occurrence: Date, minutes: Int = 10) {
        guard let reminder = reminder(id: reminderID) else { return }
        Task { await notifications.scheduleSnooze(reminderID: reminderID, title: reminder.title, occurrence: occurrence, minutes: minutes) }
    }

    func delete(_ reminder: Reminder) {
        context.delete(reminder)
        commit()
    }

    func deleteAll() {
        for reminder in all() { context.delete(reminder) }
        commit()
    }

    /// Re-plans alerts without changing data (app opened, settings changed, …).
    func refreshAlerts() {
        scheduler.reschedule(all().map(\.snapshot))
    }

    func refreshAlertsAndWait() async {
        await scheduler.rescheduleAndWait(all().map(\.snapshot))
    }

    // MARK: Private

    private func commit() {
        do {
            try context.save()
        } catch {
            Log.app.error("Saving reminders failed: \(error.localizedDescription, privacy: .public)")
        }
        refreshAlerts()
    }

    private static func cleaned(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Reminder" : trimmed
    }
}
