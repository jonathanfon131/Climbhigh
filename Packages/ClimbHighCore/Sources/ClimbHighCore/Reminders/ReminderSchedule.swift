import Foundation

/// Everything about *when* a reminder alerts.
///
/// Three layers of alerts come out of one schedule:
/// 1. **Heads-ups** (`leadTimes`) — e.g. 3 days and 2 hours before.
/// 2. **The due alert** — at the due time, as a full alarm when `ringsAlarm` is on.
/// 3. **Day-of nudges** (`dayOfNudges`) — extra reminders at set times on the
///    due day, until you mark it done.
public struct ReminderSchedule: Codable, Hashable, Sendable {
    /// The first (or only) time it's due. Always stored on a whole minute.
    public var firstDue: Date {
        didSet { firstDue = Self.wholeMinute(firstDue) }
    }
    public var repeatRule: RepeatRule
    public var leadTimes: [LeadTime]
    public var ringsAlarm: Bool
    public var dayOfNudges: [TimeOfDay]

    public init(
        firstDue: Date,
        repeatRule: RepeatRule = .never,
        leadTimes: [LeadTime] = [],
        ringsAlarm: Bool = true,
        dayOfNudges: [TimeOfDay] = []
    ) {
        self.firstDue = Self.wholeMinute(firstDue)
        self.repeatRule = repeatRule
        self.leadTimes = leadTimes
        self.ringsAlarm = ringsAlarm
        self.dayOfNudges = dayOfNudges.sorted()
    }

    /// Drops seconds so that occurrences compare exactly (a DatePicker hands
    /// back the current seconds, which would make "is this occurrence done?"
    /// checks flaky).
    public static func wholeMinute(_ date: Date) -> Date {
        let seconds = date.timeIntervalSinceReferenceDate
        return Date(timeIntervalSinceReferenceDate: (seconds / 60).rounded(.down) * 60)
    }

    // MARK: Codable — tolerant of fields added in later versions

    private enum CodingKeys: String, CodingKey {
        case firstDue, repeatRule, leadTimes, ringsAlarm, dayOfNudges
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            firstDue: try container.decode(Date.self, forKey: .firstDue),
            repeatRule: try container.decodeIfPresent(RepeatRule.self, forKey: .repeatRule) ?? .never,
            leadTimes: try container.decodeIfPresent([LeadTime].self, forKey: .leadTimes) ?? [],
            ringsAlarm: try container.decodeIfPresent(Bool.self, forKey: .ringsAlarm) ?? true,
            dayOfNudges: try container.decodeIfPresent([TimeOfDay].self, forKey: .dayOfNudges) ?? []
        )
    }
}
