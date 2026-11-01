import Foundation
import Testing
@testable import ClimbHighCore

@Suite("When reminders are due")
struct OccurrenceCalculatorTests {
    let calculator = OccurrenceCalculator(calendar: Fixture.calendar)

    @Test func oneTimeReminderOnlyInsideWindow() {
        let schedule = ReminderSchedule(firstDue: Fixture.date(2026, 11, 4, 15))
        let inside = DateInterval(start: Fixture.date(2026, 11, 1), end: Fixture.date(2026, 11, 10))
        let outside = DateInterval(start: Fixture.date(2026, 11, 5), end: Fixture.date(2026, 11, 10))
        #expect(calculator.occurrences(of: schedule, in: inside) == [Fixture.date(2026, 11, 4, 15)])
        #expect(calculator.occurrences(of: schedule, in: outside).isEmpty)
    }

    @Test func everyOtherDay() {
        let schedule = ReminderSchedule(firstDue: Fixture.date(2026, 11, 2, 9), repeatRule: RepeatRule(frequency: .daily, interval: 2))
        let window = DateInterval(start: Fixture.date(2026, 11, 2), end: Fixture.date(2026, 11, 8, 23))
        #expect(calculator.occurrences(of: schedule, in: window) == [
            Fixture.date(2026, 11, 2, 9), Fixture.date(2026, 11, 4, 9),
            Fixture.date(2026, 11, 6, 9), Fixture.date(2026, 11, 8, 9)
        ])
    }

    @Test func monthlyOnThe31stDoesNotDrift() {
        let schedule = ReminderSchedule(firstDue: Fixture.date(2026, 1, 31, 9), repeatRule: RepeatRule(frequency: .monthly))
        let window = DateInterval(start: Fixture.date(2026, 1, 1), end: Fixture.date(2026, 5, 31, 23))
        #expect(calculator.occurrences(of: schedule, in: window) == [
            Fixture.date(2026, 1, 31, 9), Fixture.date(2026, 2, 28, 9), Fixture.date(2026, 3, 31, 9),
            Fixture.date(2026, 4, 30, 9), Fixture.date(2026, 5, 31, 9)
        ])
    }

    @Test func weeklyOnChosenDays() {
        // Monday Nov 2, 2026, 7 AM, repeating Mondays and Thursdays.
        let schedule = ReminderSchedule(firstDue: Fixture.date(2026, 11, 2, 7), repeatRule: RepeatRule(frequency: .weekly, weekdays: [2, 5]))
        let window = DateInterval(start: Fixture.date(2026, 11, 1), end: Fixture.date(2026, 11, 15))
        #expect(calculator.occurrences(of: schedule, in: window) == [
            Fixture.date(2026, 11, 2, 7), Fixture.date(2026, 11, 5, 7),
            Fixture.date(2026, 11, 9, 7), Fixture.date(2026, 11, 12, 7)
        ])
    }

    @Test func everyTwoWeeks() {
        let schedule = ReminderSchedule(firstDue: Fixture.date(2026, 11, 2, 7), repeatRule: RepeatRule(frequency: .weekly, interval: 2, weekdays: [2]))
        let window = DateInterval(start: Fixture.date(2026, 11, 1), end: Fixture.date(2026, 12, 1))
        #expect(calculator.occurrences(of: schedule, in: window) == [
            Fixture.date(2026, 11, 2, 7), Fixture.date(2026, 11, 16, 7), Fixture.date(2026, 11, 30, 7)
        ])
    }

    @Test func dailyKeepsWallClockTimeAcrossDaylightSaving() {
        let schedule = ReminderSchedule(firstDue: Fixture.date(2026, 10, 31, 9), repeatRule: RepeatRule(frequency: .daily))
        let window = DateInterval(start: Fixture.date(2026, 10, 31), end: Fixture.date(2026, 11, 2, 23))
        let dates = calculator.occurrences(of: schedule, in: window)
        #expect(dates.count == 3)
        for date in dates {
            #expect(Fixture.hourAndMinute(of: date) == [9, 0])
        }
    }

    @Test func oldDailyReminderSkipsAheadQuickly() {
        let schedule = ReminderSchedule(firstDue: Fixture.date(2024, 1, 1, 9), repeatRule: RepeatRule(frequency: .daily))
        let window = DateInterval(start: Fixture.date(2026, 11, 1), end: Fixture.date(2026, 11, 3, 23))
        #expect(calculator.occurrences(of: schedule, in: window, limit: 10) == [
            Fixture.date(2026, 11, 1, 9), Fixture.date(2026, 11, 2, 9), Fixture.date(2026, 11, 3, 9)
        ])
    }

    @Test func nextYearlyOccurrence() {
        let birthday = ReminderSchedule(firstDue: Fixture.date(2020, 3, 5, 8), repeatRule: RepeatRule(frequency: .yearly))
        #expect(calculator.firstOccurrence(of: birthday, onOrAfter: Fixture.now) == Fixture.date(2027, 3, 5, 8))
    }

    @Test func dueDatesAreStoredOnWholeMinutes() {
        let withSeconds = Fixture.date(2026, 11, 4, 15).addingTimeInterval(42.7)
        #expect(ReminderSchedule(firstDue: withSeconds).firstDue == Fixture.date(2026, 11, 4, 15))
    }
}
