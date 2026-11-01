import Foundation
import Testing
@testable import ClimbHighCore

@Suite("Which alerts get scheduled")
struct AlertPlannerTests {
    let planner = AlertPlanner(calendar: Fixture.calendar)

    /// Due Wed Nov 4 at 3 PM; heads-ups 1 day and 2 hours before; nudges at 9, 1 and 6.
    func dentist(completed: Set<Date> = [], archived: Bool = false) -> ReminderSnapshot {
        let schedule = ReminderSchedule(
            firstDue: Fixture.date(2026, 11, 4, 15),
            leadTimes: [LeadTime(amount: 1, unit: .days), LeadTime(amount: 2, unit: .hours)],
            ringsAlarm: true,
            dayOfNudges: [TimeOfDay(hour: 9), TimeOfDay(hour: 13), TimeOfDay(hour: 18)]
        )
        return ReminderSnapshot(id: UUID(), title: "Dentist", schedule: schedule, completedOccurrences: completed, isArchived: archived)
    }

    @Test func plansAllThreeLayers() {
        let alerts = planner.plan(for: dentist(), now: Fixture.now)
        #expect(alerts.filter { $0.kind == .headsUp }.map(\.fireDate).sorted() == [Fixture.date(2026, 11, 3, 15), Fixture.date(2026, 11, 4, 13)])
        #expect(alerts.filter { $0.kind == .due }.map(\.fireDate) == [Fixture.date(2026, 11, 4, 15)])
        #expect(alerts.filter { $0.kind == .nudge }.map(\.fireDate) == [
            Fixture.date(2026, 11, 4, 9), Fixture.date(2026, 11, 4, 13), Fixture.date(2026, 11, 4, 18)
        ])
        #expect(alerts.map(\.fireDate) == alerts.map(\.fireDate).sorted())
    }

    @Test func skipsAlertsInThePast() {
        let alerts = planner.plan(for: dentist(), now: Fixture.date(2026, 11, 4, 14))
        #expect(alerts.map(\.kind) == [.due, .nudge])
    }

    @Test func doneOccurrencesStopAlerting() {
        let done = dentist(completed: [Fixture.date(2026, 11, 4, 15)])
        #expect(planner.plan(for: done, now: Fixture.now).isEmpty)
        #expect(planner.plan(for: dentist(archived: true), now: Fixture.now).isEmpty)
    }

    @Test func respectsTheHorizon() {
        let daily = ReminderSnapshot(
            id: UUID(), title: "Stretch",
            schedule: ReminderSchedule(firstDue: Fixture.date(2026, 11, 1, 18), repeatRule: RepeatRule(frequency: .daily), ringsAlarm: false)
        )
        let alerts = planner.plan(for: daily, now: Fixture.now, horizonDays: 3)
        #expect(alerts.map(\.fireDate) == [
            Fixture.date(2026, 11, 1, 18), Fixture.date(2026, 11, 2, 18), Fixture.date(2026, 11, 3, 18)
        ])
    }

    @Test func headsUpForAnOccurrenceBeyondTheHorizonIsKept() {
        let trip = ReminderSnapshot(
            id: UUID(), title: "Trip",
            schedule: ReminderSchedule(firstDue: Fixture.date(2026, 11, 12, 9), leadTimes: [LeadTime(amount: 1, unit: .weeks)])
        )
        let alerts = planner.plan(for: trip, now: Fixture.now, horizonDays: 7)
        #expect(alerts.map(\.kind) == [.headsUp])
        #expect(alerts.first?.fireDate == Fixture.date(2026, 11, 5, 9))
    }

    @Test func identifiersAreStableBetweenRuns() {
        let reminder = dentist()
        let first = planner.plan(for: [reminder], now: Fixture.now).map(\.identifier)
        let second = planner.plan(for: [reminder], now: Fixture.now).map(\.identifier)
        #expect(first == second)
        #expect(Set(first).count == first.count)
    }
}

@Suite("Reminder list sections")
struct ReminderAgendaTests {
    let agenda = ReminderAgenda(calendar: Fixture.calendar)

    @Test func sectionsByDate() {
        let overdue = ReminderSnapshot(id: UUID(), title: "A", schedule: ReminderSchedule(firstDue: Fixture.date(2026, 10, 30, 9)))
        let today = ReminderSnapshot(id: UUID(), title: "B", schedule: ReminderSchedule(firstDue: Fixture.date(2026, 11, 1, 18)))
        let later = ReminderSnapshot(id: UUID(), title: "C", schedule: ReminderSchedule(firstDue: Fixture.date(2026, 11, 9, 9)))
        let done = ReminderSnapshot(id: UUID(), title: "D", schedule: ReminderSchedule(firstDue: Fixture.date(2026, 11, 2, 9)), isArchived: true)

        let entries = agenda.entries(for: [later, done, today, overdue], now: Fixture.now)
        #expect(entries.map(\.section) == [.overdue, .today, .upcoming, .done])
    }

    @Test func repeatingReminderMovesOnAfterTodayIsDone() {
        let daily = ReminderSchedule(firstDue: Fixture.date(2026, 10, 1, 8), repeatRule: RepeatRule(frequency: .daily))
        let open = ReminderSnapshot(id: UUID(), title: "Vitamins", schedule: daily)
        #expect(agenda.nextOpenOccurrence(of: open, now: Fixture.now) == Fixture.date(2026, 11, 1, 8))

        let doneToday = ReminderSnapshot(id: open.id, title: "Vitamins", schedule: daily, completedOccurrences: [Fixture.date(2026, 11, 1, 8)])
        #expect(agenda.nextOpenOccurrence(of: doneToday, now: Fixture.now) == Fixture.date(2026, 11, 2, 8))
    }
}
