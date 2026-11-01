import Foundation

public enum RepeatFrequency: String, Codable, CaseIterable, Sendable {
    case never, daily, weekly, monthly, yearly

    var unitName: String {
        switch self {
        case .never: ""
        case .daily: "day"
        case .weekly: "week"
        case .monthly: "month"
        case .yearly: "year"
        }
    }
}

/// How a reminder repeats: every N days/weeks/months/years.
/// Weekly rules can also pick specific weekdays ("every week on Mon and Thu").
public struct RepeatRule: Codable, Hashable, Sendable {
    public var frequency: RepeatFrequency
    /// Every `interval` units. Always at least 1.
    public var interval: Int
    /// Weekly rules only. Uses the Calendar convention: 1 = Sunday ... 7 = Saturday.
    /// Empty means "the same weekday as the first due date".
    public var weekdays: Set<Int>

    public static let never = RepeatRule(frequency: .never)

    public init(frequency: RepeatFrequency, interval: Int = 1, weekdays: Set<Int> = []) {
        self.frequency = frequency
        self.interval = max(1, interval)
        self.weekdays = weekdays.filter { (1...7).contains($0) }
    }

    public var isRepeating: Bool { frequency != .never }

    /// Plain-English summary, e.g. "Every 2 weeks on Mon, Thu".
    public var summary: String {
        guard isRepeating else { return "Doesn't repeat" }
        let unit = frequency.unitName
        var text = interval == 1 ? "Every \(unit)" : "Every \(interval) \(unit)s"
        if frequency == .weekly, !weekdays.isEmpty {
            let names = weekdays.sorted().map { Self.shortWeekdayNames[$0 - 1] }
            text += " on " + names.joined(separator: ", ")
        }
        return text
    }

    public static let shortWeekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
}

extension RepeatRule {
    /// One word for tight spaces: "Daily", "Weekly", "Every 2 wks", "Monthly"…
    public var shortLabel: String {
        guard isRepeating else { return "Once" }
        if interval == 1 {
            switch frequency {
            case .never: return "Once"
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            case .yearly: return "Yearly"
            }
        }
        let unit: String
        switch frequency {
        case .never: return "Once"
        case .daily: unit = "days"
        case .weekly: unit = "wks"
        case .monthly: unit = "mos"
        case .yearly: unit = "yrs"
        }
        return "Every \(interval) \(unit)"
    }
}
