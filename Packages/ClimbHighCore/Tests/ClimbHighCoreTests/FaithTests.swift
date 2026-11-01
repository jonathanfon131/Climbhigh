import Foundation
import Testing
@testable import ClimbHighCore

@Suite("Daily verse")
struct DailyVerseTests {
    @Test func bundledListIsComplete() throws {
        let library = try VerseLibrary.bundled()
        #expect(library.verses.count >= 366, "at least a year without repeats")
        #expect(library.translation.contains("Berean Standard Bible"))
        #expect(Set(library.verses.map(\.reference)).count == library.verses.count, "no duplicates")
        for verse in library.verses {
            #expect(!verse.text.isEmpty && !verse.reference.isEmpty)
            #expect(verse.text.count < 400, "fits a notification: \(verse.reference)")
        }
    }

    @Test func knownVerseMatchesTheSource() throws {
        let library = try VerseLibrary.bundled()
        let john316 = library.verses.first { $0.reference == "John 3:16" }
        #expect(john316?.text == "For God so loved the world that He gave His one and only Son, that everyone who believes in Him shall not perish but have eternal life.")
    }

    @Test func sameVerseAllDayNewVerseTomorrow() {
        let library = VerseLibrary(translation: "Test", verses: (0..<5).map { DailyVerse(reference: "R\($0)", text: "T\($0)") })
        let calendar = Fixture.calendar
        let morning = Fixture.date(2026, 11, 1, 6)
        let night = Fixture.date(2026, 11, 1, 23, 59)
        let tomorrow = Fixture.date(2026, 11, 2, 6)
        #expect(library.index(for: morning, calendar: calendar) == library.index(for: night, calendar: calendar))
        #expect(library.index(for: tomorrow, calendar: calendar) == (library.index(for: morning, calendar: calendar) + 1) % 5)
        // Wraps around and never goes negative, even before the start date.
        #expect((0..<5).contains(library.index(for: Fixture.date(2025, 6, 1), calendar: calendar)))
    }
}

@Suite("Reading streaks")
struct ReadingStreakTests {
    let calendar = Fixture.calendar

    func days(_ list: [(Int, Int, Int)]) -> Set<DayStamp> {
        Set(list.map { DayStamp(year: $0.0, month: $0.1, day: $0.2) })
    }

    @Test func countsConsecutiveDaysAcrossDaylightSaving() {
        // Oct 30 – Nov 1, 2026 crosses the fall-back night.
        let read = days([(2026, 10, 30), (2026, 10, 31), (2026, 11, 1)])
        let streak = ReadingStreak(readDays: read, today: Fixture.now, calendar: calendar)
        #expect(streak.current == 3)
        #expect(streak.readToday)
        #expect(streak.isMilestone)
    }

    @Test func notReadYetTodayKeepsTheStreakAlive() {
        let read = days([(2026, 10, 30), (2026, 10, 31)])
        let streak = ReadingStreak(readDays: read, today: Fixture.now, calendar: calendar)
        #expect(streak.current == 2)
        #expect(!streak.readToday)
    }

    @Test func missingADayResets() {
        let read = days([(2026, 10, 28), (2026, 10, 29), (2026, 10, 30)])
        let streak = ReadingStreak(readDays: read, today: Fixture.now, calendar: calendar)
        #expect(streak.current == 0)
        #expect(streak.best == 3)
        #expect(streak.total == 3)
    }

    @Test func bestStreakAcrossMonthsAndGaps() {
        let read = days([(2026, 9, 29), (2026, 9, 30), (2026, 10, 1), (2026, 10, 2), (2026, 10, 10), (2026, 11, 1)])
        let streak = ReadingStreak(readDays: read, today: Fixture.now, calendar: calendar)
        #expect(streak.best == 4)
        #expect(streak.current == 1)
        #expect(streak.nextMilestone == 3)
    }

    @Test func recentDaysEndToday() {
        let read = days([(2026, 10, 31), (2026, 11, 1)])
        let recent = ReadingStreak.recentDays(3, readDays: read, today: Fixture.now, calendar: calendar)
        #expect(recent.map { $0.day.description } == ["2026-10-30", "2026-10-31", "2026-11-01"])
        #expect(recent.map { $0.read } == [false, true, true])
    }

    @Test func dayStampText() {
        #expect(DayStamp("2026-11-01") == DayStamp(year: 2026, month: 11, day: 1))
        #expect(DayStamp(year: 2026, month: 3, day: 5).description == "2026-03-05")
        #expect(DayStamp("nope") == nil)
    }
}
