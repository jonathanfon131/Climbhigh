import Foundation

/// A calendar day ("2026-11-01"), independent of time and time zone shifts.
public struct DayStamp: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
    }

    /// Parses "2026-11-01".
    public init?(_ text: String) {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

    public static func < (lhs: DayStamp, rhs: DayStamp) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// Noon on that day — safely away from daylight-saving jumps.
    public func date(calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
    }

    public func adding(days: Int, calendar: Calendar) -> DayStamp? {
        guard let date = date(calendar: calendar),
              let moved = calendar.date(byAdding: .day, value: days, to: date)
        else { return nil }
        return DayStamp(moved, calendar: calendar)
    }
}

/// Daily-verse reading streak.
///
/// - `current`: consecutive days read, ending today — or ending yesterday if
///   today isn't read *yet* (the streak is still alive until midnight).
/// - `best`: longest run ever.
public struct ReadingStreak: Equatable, Sendable {
    public let current: Int
    public let best: Int
    public let total: Int
    public let readToday: Bool

    /// Streak lengths that get a celebration.
    public static let milestones = [3, 7, 14, 21, 30, 50, 100, 150, 200, 365, 500, 730, 1000]

    public init(readDays: Set<DayStamp>, today: Date, calendar: Calendar) {
        let todayStamp = DayStamp(today, calendar: calendar)
        readToday = readDays.contains(todayStamp)
        total = readDays.count

        var run = 0
        var cursor: DayStamp? = readToday ? todayStamp : todayStamp.adding(days: -1, calendar: calendar)
        while let day = cursor, readDays.contains(day) {
            run += 1
            cursor = day.adding(days: -1, calendar: calendar)
        }
        current = run

        var longest = 0
        var length = 0
        var previous: DayStamp?
        for day in readDays.sorted() {
            if let previous, previous.adding(days: 1, calendar: calendar) == day {
                length += 1
            } else {
                length = 1
            }
            longest = max(longest, length)
            previous = day
        }
        best = longest
    }

    /// Whether today's streak length is a milestone worth celebrating.
    public var isMilestone: Bool { readToday && Self.milestones.contains(current) }

    /// The next milestone to aim for.
    public var nextMilestone: Int? { Self.milestones.first { $0 > current } }

    /// Read / not read for the last `count` days, oldest first, ending today.
    public static func recentDays(_ count: Int, readDays: Set<DayStamp>, today: Date, calendar: Calendar) -> [(day: DayStamp, read: Bool)] {
        let todayStamp = DayStamp(today, calendar: calendar)
        return (0..<count).reversed().compactMap { offset in
            todayStamp.adding(days: -offset, calendar: calendar).map { ($0, readDays.contains($0)) }
        }
    }
}
