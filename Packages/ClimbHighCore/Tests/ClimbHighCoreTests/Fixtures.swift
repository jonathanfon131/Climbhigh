import Foundation
@testable import ClimbHighCore

/// Fixed calendar and dates so tests never depend on the machine's clock or time zone.
/// Central Time (Pensacola) — and Sunday, Nov 1 2026 is the day US clocks fall back,
/// which makes daylight-saving bugs show up.
enum Fixture {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        calendar.firstWeekday = 1 // Sunday
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Sunday, November 1, 2026, 3:00 PM Central.
    static let now = date(2026, 11, 1, 15, 0)

    static func hourAndMinute(of date: Date) -> [Int] {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return [parts.hour!, parts.minute!]
    }
}
