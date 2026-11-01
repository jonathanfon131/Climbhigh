import Foundation

/// A read-only copy of a reminder: everything the planner needs and nothing
/// tied to the database. Keeps planning logic free of storage concerns.
public struct ReminderSnapshot: Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let schedule: ReminderSchedule
    /// Occurrences already marked done (whole-minute dates).
    public let completedOccurrences: Set<Date>
    /// Finished one-time reminders are archived and never alert again.
    public let isArchived: Bool

    public init(id: UUID, title: String, schedule: ReminderSchedule, completedOccurrences: Set<Date> = [], isArchived: Bool = false) {
        self.id = id
        self.title = title
        self.schedule = schedule
        self.completedOccurrences = completedOccurrences
        self.isArchived = isArchived
    }
}

public enum AlertKind: String, Codable, Sendable {
    /// Early warning before the due time.
    case headsUp
    /// The due time itself.
    case due
    /// Extra reminder on the due day.
    case nudge
}

/// One alert the phone should show at `fireDate`.
public struct PlannedAlert: Hashable, Sendable {
    public let reminderID: UUID
    public let occurrence: Date
    public let kind: AlertKind
    public let fireDate: Date
    /// For heads-ups: the lead time that produced it (e.g. "3 days").
    public let leadTime: LeadTime?

    /// Stable name for this alert. Re-planning produces the same identifier,
    /// so the OS-level request is replaced rather than duplicated.
    public var identifier: String {
        let occurrenceStamp = Int(occurrence.timeIntervalSince1970)
        let fireStamp = Int(fireDate.timeIntervalSince1970)
        return "reminder.\(reminderID.uuidString).\(occurrenceStamp).\(kind.rawValue).\(fireStamp)"
    }
}

/// Turns reminders into the concrete list of alerts to schedule.
///
/// Pure function of its inputs: same reminders + same `now` → same plan.
public struct AlertPlanner: Sendable {
    public let calendar: Calendar
    private let calculator: OccurrenceCalculator

    public init(calendar: Calendar) {
        self.calendar = calendar
        self.calculator = OccurrenceCalculator(calendar: calendar)
    }

    /// All alerts that fire after `now` and within `horizonDays`, soonest first.
    public func plan(for reminders: [ReminderSnapshot], now: Date, horizonDays: Int = 30) -> [PlannedAlert] {
        reminders
            .flatMap { plan(for: $0, now: now, horizonDays: horizonDays) }
            .sorted { ($0.fireDate, $0.identifier) < ($1.fireDate, $1.identifier) }
    }

    public func plan(for reminder: ReminderSnapshot, now: Date, horizonDays: Int = 30) -> [PlannedAlert] {
        guard !reminder.isArchived,
              let horizonEnd = calendar.date(byAdding: .day, value: horizonDays, to: now)
        else { return [] }

        let schedule = reminder.schedule
        // Look slightly into the past (for today's nudges after the due time)
        // and past the horizon (a heads-up inside the horizon can belong to an
        // occurrence after it).
        let longestLead = schedule.leadTimes
            .compactMap { $0.fireDate(before: horizonEnd, calendar: calendar) }
            .min() ?? horizonEnd
        let leadSpan = horizonEnd.timeIntervalSince(longestLead)
        let windowStart = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let window = DateInterval(start: windowStart, end: horizonEnd.addingTimeInterval(leadSpan))

        var alerts: [PlannedAlert] = []
        let openOccurrences = calculator.occurrences(of: schedule, in: window)
            .filter { !reminder.completedOccurrences.contains($0) }
        for occurrence in openOccurrences {
            func add(_ kind: AlertKind, at fireDate: Date, lead: LeadTime? = nil) {
                guard fireDate > now, fireDate <= horizonEnd else { return }
                alerts.append(PlannedAlert(reminderID: reminder.id, occurrence: occurrence, kind: kind, fireDate: fireDate, leadTime: lead))
            }

            for lead in schedule.leadTimes {
                if let fireDate = lead.fireDate(before: occurrence, calendar: calendar) {
                    add(.headsUp, at: fireDate, lead: lead)
                }
            }
            add(.due, at: occurrence)
            for time in Set(schedule.dayOfNudges) {
                guard let fireDate = time.on(occurrence, calendar: calendar), fireDate != occurrence else { continue }
                add(.nudge, at: fireDate)
            }
        }
        return alerts.sorted { $0.fireDate < $1.fireDate }
    }
}
