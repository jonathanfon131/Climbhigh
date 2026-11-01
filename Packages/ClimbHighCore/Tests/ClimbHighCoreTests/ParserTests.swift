import Foundation
import Testing
@testable import ClimbHighCore

/// "Now" for every case below: Sunday, Nov 1, 2026, 3:00 PM Central.
@Suite("Understanding dates in plain English")
struct DatePhraseParserTests {
    let parser = DatePhraseParser(calendar: Fixture.calendar)

    func date(_ text: String) -> Date? {
        parser.parse(text, now: Fixture.now)?.date
    }

    @Test func relativeTimes() {
        #expect(date("in 20 minutes") == Fixture.date(2026, 11, 1, 15, 20))
        #expect(date("in an hour") == Fixture.date(2026, 11, 1, 16, 0))
        #expect(date("in half an hour") == Fixture.date(2026, 11, 1, 15, 30))
        #expect(date("in five minutes") == Fixture.date(2026, 11, 1, 15, 5))
        #expect(date("in 2 days at 10am") == Fixture.date(2026, 11, 3, 10, 0))
    }

    @Test func namedDays() {
        #expect(date("tomorrow at 5pm") == Fixture.date(2026, 11, 2, 17, 0))
        #expect(date("tomorrow") == Fixture.date(2026, 11, 2, 9, 0))
        #expect(date("tonight") == Fixture.date(2026, 11, 1, 20, 0))
        #expect(date("this evening at 7") == Fixture.date(2026, 11, 1, 19, 0))
        #expect(date("friday at 9:15") == Fixture.date(2026, 11, 6, 9, 15))
        #expect(date("sunday at 6pm") == Fixture.date(2026, 11, 1, 18, 0))
        #expect(date("sunday at 9am") == Fixture.date(2026, 11, 8, 9, 0))
        #expect(date("next sunday") == Fixture.date(2026, 11, 8, 9, 0))
    }

    @Test func calendarDates() {
        #expect(date("march 5th") == Fixture.date(2027, 3, 5, 9, 0))
        #expect(date("12/25 at noon") == Fixture.date(2026, 12, 25, 12, 0))
        #expect(date("feb 31") == nil)
    }

    @Test func timesWithoutAmPm() {
        #expect(date("at 8") == Fixture.date(2026, 11, 1, 20, 0))   // 8 AM passed, 8 PM ahead
        #expect(date("at 4") == Fixture.date(2026, 11, 1, 16, 0))   // 1–6 means PM
        #expect(date("at 7:30 am") == Fixture.date(2026, 11, 2, 7, 30))
        #expect(date("at five thirty") == Fixture.date(2026, 11, 1, 17, 30))
        #expect(date("at midnight") == Fixture.date(2026, 11, 2, 0, 0))
    }

    @Test func keepsTheRestOfTheSentence() {
        let match = parser.parse("call Mom tomorrow at 5pm", now: Fixture.now)
        #expect(match?.remainder == "call Mom")
        #expect(parser.parse("buy milk", now: Fixture.now) == nil)
    }
}

@Suite("Understanding voice commands")
struct CommandParserTests {
    let parser = CommandParser(dates: DatePhraseParser(calendar: Fixture.calendar))

    func parse(_ text: String) -> AssistantCommand {
        parser.parse(text, now: Fixture.now)
    }

    @Test func reminders() {
        #expect(parse("Remind me to call Mom tomorrow at 5pm.") == .createReminder(title: "Call Mom", due: Fixture.date(2026, 11, 2, 17)))
        #expect(parse("remind me tomorrow to pay rent") == .createReminder(title: "Pay rent", due: Fixture.date(2026, 11, 2, 9)))
        #expect(parse("Hey can you remind me to stretch in 10 minutes") == .createReminder(title: "Stretch", due: Fixture.date(2026, 11, 1, 15, 10)))
        #expect(parse("Set a reminder for Friday at 9 to email Jake") == .createReminder(title: "Email Jake", due: Fixture.date(2026, 11, 6, 9)))
        #expect(parse("remind me to drink water") == .createReminder(title: "Drink water", due: nil))
    }

    @Test func notes() {
        #expect(parse("Note: test the new landing page") == .createNote(text: "Test the new landing page"))
        #expect(parse("take a note that the gate code is 4412") == .createNote(text: "The gate code is 4412"))
        #expect(parse("notebook ideas") == .unrecognized)
    }

    @Test func restTimers() {
        #expect(parse("start heavy set") == .startRest(.heavy))
        #expect(parse("Failure rest") == .startRest(.failure))
        #expect(parse("light set timer") == .startRest(.light))
    }

    @Test func questions() {
        #expect(parse("What's coming up?") == .listUpcoming)
        #expect(parse("how do I improve my sales pitch") == .unrecognized)
    }
}
