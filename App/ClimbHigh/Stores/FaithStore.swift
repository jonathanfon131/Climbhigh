import ClimbHighCore
import Foundation
import Observation
import SwiftData

/// Daily verse + reading streak.
///
/// - Today's verse comes from the bundled Berean Standard Bible list (ClimbHighCore).
/// - Tapping "I read it" (in the app or on the morning notification) saves a
///   `VerseRead` for today; the streak is recomputed from those days.
/// - A morning notification is scheduled for each of the next 7 days, each
///   showing that day's verse. Today's is skipped once you've read it.
@MainActor
@Observable
final class FaithStore {
    private(set) var library: VerseLibrary?
    private(set) var readDays: Set<DayStamp> = []
    /// The calendar day the screen is showing; moved forward when the app opens on a new day.
    private(set) var currentDay: DayStamp
    /// Set when a mark-as-read just hit a milestone (3, 7, 14, 30… days) — the UI celebrates.
    var celebratingMilestone: Int?

    private let context: ModelContext
    private let settings: SettingsStore
    private let notifications: NotificationService
    let calendar: Calendar

    init(context: ModelContext, settings: SettingsStore, notifications: NotificationService, calendar: Calendar = .current) {
        self.context = context
        self.settings = settings
        self.notifications = notifications
        self.calendar = calendar
        self.currentDay = DayStamp(.now, calendar: calendar)
        do {
            library = try VerseLibrary.bundled()
        } catch {
            Log.faith.error("Verse list failed to load: \(error.localizedDescription, privacy: .public)")
        }
        reloadReadDays()
    }

    // MARK: Reading

    var todayVerse: DailyVerse? {
        guard let date = currentDay.date(calendar: calendar) else { return nil }
        return library?.verse(for: date, calendar: calendar)
    }

    var streak: ReadingStreak {
        ReadingStreak(readDays: readDays, today: currentDay.date(calendar: calendar) ?? .now, calendar: calendar)
    }

    func recentDays(_ count: Int = 14) -> [(day: DayStamp, read: Bool)] {
        ReadingStreak.recentDays(count, readDays: readDays, today: currentDay.date(calendar: calendar) ?? .now, calendar: calendar)
    }

    // MARK: Writing

    /// Marks today's verse as read. Safe to call more than once a day.
    func markTodayRead() {
        refreshDay()
        guard !readDays.contains(currentDay) else { return }
        context.insert(VerseRead(day: currentDay.description))
        do {
            try context.save()
        } catch {
            Log.faith.error("Saving verse read failed: \(error.localizedDescription, privacy: .public)")
        }
        reloadReadDays()
        if streak.isMilestone { celebratingMilestone = streak.current }
        refreshReminders()
    }

    /// Adds read days from a backup (keeps existing ones).
    func importReadDays(_ days: [String]) {
        let incoming = Set(days.compactMap { DayStamp($0) })
        for stamp in incoming.subtracting(readDays) {
            context.insert(VerseRead(day: stamp.description))
        }
        try? context.save()
        reloadReadDays()
        refreshReminders()
    }

    func deleteAll() {
        for row in (try? context.fetch(FetchDescriptor<VerseRead>())) ?? [] { context.delete(row) }
        try? context.save()
        reloadReadDays()
    }

    /// Call when the app opens: moves to a new day after midnight and tops up notifications.
    func refreshDay() {
        let today = DayStamp(.now, calendar: calendar)
        if today != currentDay { currentDay = today }
    }

    /// Schedules the next 7 mornings' verse notifications (or clears them if turned off).
    func refreshReminders() {
        let preferences = settings.settings
        guard preferences.verseReminderEnabled, let library else {
            Task { await notifications.replaceVerseReminders([]) }
            return
        }
        let now = Date.now
        let streakNow = streak.current
        var items: [(fireDate: Date, verse: DailyVerse, streak: Int)] = []
        for offset in 0..<NotificationService.Budget.verses {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)),
                  let fireDate = preferences.verseReminderTime.on(day, calendar: calendar),
                  fireDate > now,
                  let verse = library.verse(for: day, calendar: calendar)
            else { continue }
            if offset == 0, readDays.contains(DayStamp(day, calendar: calendar)) { continue }
            items.append((fireDate, verse, streakNow))
        }
        Task { await notifications.replaceVerseReminders(items) }
    }

    private func reloadReadDays() {
        let rows = (try? context.fetch(FetchDescriptor<VerseRead>())) ?? []
        readDays = Set(rows.compactMap { DayStamp($0.day) })
    }
}
