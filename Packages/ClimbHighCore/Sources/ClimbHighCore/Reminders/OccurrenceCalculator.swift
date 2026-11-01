import Foundation

/// Works out the dates a reminder is due, given its repeat rule.
///
/// Every occurrence is computed from the *first* due date (never by stepping
/// from the previous occurrence), so monthly reminders on the 31st don't drift
/// to the 28th after February.
public struct OccurrenceCalculator: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar) {
        self.calendar = calendar
    }

    /// Every occurrence inside `interval` (inclusive), oldest first.
    /// `limit` protects against runaway loops on very long windows.
    public func occurrences(of schedule: ReminderSchedule, in interval: DateInterval, limit: Int = 500) -> [Date] {
        let first = schedule.firstDue
        let rule = schedule.repeatRule
        guard first <= interval.end else { return [] }

        switch rule.frequency {
        case .never:
            return interval.contains(first) ? [first] : []
        case .daily:
            return stepped(from: first, component: .day, step: rule.interval, in: interval, limit: limit)
        case .weekly where rule.weekdays.isEmpty:
            return stepped(from: first, component: .day, step: rule.interval * 7, in: interval, limit: limit)
        case .weekly:
            return weekly(from: first, weekdays: rule.weekdays, everyWeeks: rule.interval, in: interval, limit: limit)
        case .monthly:
            return stepped(from: first, component: .month, step: rule.interval, in: interval, limit: limit)
        case .yearly:
            return stepped(from: first, component: .year, step: rule.interval, in: interval, limit: limit)
        }
    }

    /// The first occurrence at or after `date`, if there is one.
    public func firstOccurrence(of schedule: ReminderSchedule, onOrAfter date: Date) -> Date? {
        let rule = schedule.repeatRule
        guard rule.isRepeating else {
            return schedule.firstDue >= date ? schedule.firstDue : nil
        }
        // Look far enough ahead to always contain one full repeat period.
        let periodDays: Int
        switch rule.frequency {
        case .never, .daily: periodDays = 1
        case .weekly: periodDays = 7
        case .monthly: periodDays = 31
        case .yearly: periodDays = 366
        }
        let start = max(date, schedule.firstDue)
        guard let end = calendar.date(byAdding: .day, value: periodDays * rule.interval + 7, to: start) else { return nil }
        return occurrences(of: schedule, in: DateInterval(start: date, end: max(date, end)), limit: 1).first
    }

    // MARK: - Private

    /// first, first + step, first + 2·step, … (each computed from `first`).
    private func stepped(from first: Date, component: Calendar.Component, step: Int, in interval: DateInterval, limit: Int) -> [Date] {
        var results: [Date] = []
        var index = estimatedStartIndex(from: first, to: interval.start, component: component, step: step)

        while results.count < limit {
            guard let date = calendar.date(byAdding: component, value: index * step, to: first) else { break }
            if date > interval.end { break }
            if date >= interval.start { results.append(date) }
            index += 1
        }
        return results
    }

    /// Skips ahead so a daily reminder created two years ago doesn't walk
    /// through 700 past dates. Starts one step early to be safe.
    private func estimatedStartIndex(from first: Date, to windowStart: Date, component: Calendar.Component, step: Int) -> Int {
        guard windowStart > first else { return 0 }
        let elapsed = calendar.dateComponents([component], from: first, to: windowStart)
        let units: Int
        switch component {
        case .day: units = elapsed.day ?? 0
        case .month: units = elapsed.month ?? 0
        case .year: units = elapsed.year ?? 0
        default: units = 0
        }
        return max(0, units / max(step, 1) - 1)
    }

    /// Weekly on chosen weekdays, every `everyWeeks` weeks, starting the week of `first`.
    private func weekly(from first: Date, weekdays: Set<Int>, everyWeeks: Int, in interval: DateInterval, limit: Int) -> [Date] {
        let time = TimeOfDay(of: first, calendar: calendar)
        let firstWeekStart = startOfWeek(containing: first)
        let windowWeekStart = startOfWeek(containing: max(first, interval.start))
        let weeksToWindow = (calendar.dateComponents([.day], from: firstWeekStart, to: windowWeekStart).day ?? 0) / 7
        // Round down to a week that is actually "on" for this rule.
        var weekIndex = max(0, (weeksToWindow / everyWeeks - 1) * everyWeeks)

        var results: [Date] = []
        while results.count < limit {
            guard let weekStart = calendar.date(byAdding: .day, value: weekIndex * 7, to: firstWeekStart) else { break }
            if weekStart > interval.end { break }
            for offset in 0..<7 {
                guard
                    let day = calendar.date(byAdding: .day, value: offset, to: weekStart),
                    weekdays.contains(calendar.component(.weekday, from: day)),
                    let date = time.on(day, calendar: calendar)
                else { continue }
                if date >= first, interval.contains(date), results.count < limit {
                    results.append(date)
                }
            }
            weekIndex += everyWeeks
        }
        return results
    }

    private func startOfWeek(containing date: Date) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: day) ?? day
    }
}
