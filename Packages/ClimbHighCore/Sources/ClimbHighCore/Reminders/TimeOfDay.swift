import Foundation

/// A wall-clock time such as 9:30, independent of any date.
///
/// Used for "remind me on the day at 9:00, 13:00 and 18:00" style settings.
public struct TimeOfDay: Codable, Hashable, Comparable, Sendable {
    /// 0...23
    public var hour: Int
    /// 0...59
    public var minute: Int

    public init(hour: Int, minute: Int = 0) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    /// The time-of-day part of `date`.
    public init(of date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    /// This time on the same calendar day as `day`.
    public func on(_ day: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }

    /// "9:05 AM" style label (12-hour clock).
    public var label: String {
        let suffix = hour < 12 ? "AM" : "PM"
        let twelveHour = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d", twelveHour, minute) + " " + suffix
    }
}
