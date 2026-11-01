import Foundation

/// Groups reminders into the sections shown on screen.
public enum AgendaSection: String, CaseIterable, Sendable {
    case overdue = "Overdue"
    case today = "Today"
    case upcoming = "Upcoming"
    case done = "Done"
}

public struct AgendaEntry: Hashable, Sendable {
    public let reminderID: UUID
    /// The occurrence you should act on next. `nil` when the reminder is finished.
    public let occurrence: Date?
    public let section: AgendaSection
}

public struct ReminderAgenda: Sendable {
    public let calendar: Calendar
    private let calculator: OccurrenceCalculator

    public init(calendar: Calendar) {
        self.calendar = calendar
        self.calculator = OccurrenceCalculator(calendar: calendar)
    }

    /// The occurrence a reminder is waiting on.
    ///
    /// - One-time: its due date until marked done (even if days overdue).
    /// - Repeating: the earliest not-done occurrence from the start of today.
    ///   Missed days in the past are not piled up — only today onward counts.
    public func nextOpenOccurrence(of reminder: ReminderSnapshot, now: Date) -> Date? {
        guard !reminder.isArchived else { return nil }
        let schedule = reminder.schedule

        guard schedule.repeatRule.isRepeating else {
            return reminder.completedOccurrences.contains(schedule.firstDue) ? nil : schedule.firstDue
        }

        var searchFrom = calendar.startOfDay(for: now)
        // A handful of tries is plenty: each loop skips one completed occurrence.
        for _ in 0..<32 {
            guard let next = calculator.firstOccurrence(of: schedule, onOrAfter: searchFrom) else { return nil }
            if !reminder.completedOccurrences.contains(next) { return next }
            searchFrom = next.addingTimeInterval(60)
        }
        return nil
    }

    public func section(for occurrence: Date?, now: Date) -> AgendaSection {
        guard let occurrence else { return .done }
        if calendar.isDate(occurrence, inSameDayAs: now) { return .today }
        return occurrence < now ? .overdue : .upcoming
    }

    /// Every reminder placed in a section, sorted by when it's next due.
    public func entries(for reminders: [ReminderSnapshot], now: Date) -> [AgendaEntry] {
        reminders
            .map { reminder in
                let next = nextOpenOccurrence(of: reminder, now: now)
                return AgendaEntry(reminderID: reminder.id, occurrence: next, section: section(for: next, now: now))
            }
            .sorted { lhs, rhs in
                switch (lhs.occurrence, rhs.occurrence) {
                case let (l?, r?): l < r
                case (.some, .none): true
                case (.none, .some): false
                case (.none, .none): lhs.reminderID.uuidString < rhs.reminderID.uuidString
                }
            }
    }
}
