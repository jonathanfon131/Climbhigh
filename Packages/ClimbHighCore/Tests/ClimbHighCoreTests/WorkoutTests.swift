import Foundation
import Testing
@testable import ClimbHighCore

@Suite("Rest timer math")
struct RestPeriodTests {
    let start = Fixture.now

    @Test func countsDownFromDates() {
        let rest = RestPeriod(intensity: .heavy, startedAt: start, duration: 180)
        #expect(rest.remaining(at: start.addingTimeInterval(60)) == 120)
        #expect(rest.progress(at: start.addingTimeInterval(90)) == 0.5)
        #expect(!rest.isFinished(at: start.addingTimeInterval(179)))
        #expect(rest.isFinished(at: start.addingTimeInterval(180)))
        #expect(rest.remaining(at: start.addingTimeInterval(500)) == 0)
    }

    @Test func addingAndRemovingTime() {
        var rest = RestPeriod(intensity: .light, startedAt: start, duration: 90)
        rest.adjust(by: 15, now: start.addingTimeInterval(10))
        #expect(rest.duration == 105)

        // Taking away more than is left ends the rest "now", never in the past.
        let now = start.addingTimeInterval(30)
        rest.adjust(by: -1_000, now: now)
        #expect(rest.endsAt == now)
    }

    @Test func evidenceBasedDefaultsAndLimits() {
        var presets = RestPresets.evidenceBased
        #expect(presets.seconds(for: .light) == 90)
        #expect(presets.seconds(for: .heavy) == 180)
        #expect(presets.seconds(for: .failure) == 240)

        presets.setSeconds(5, for: .light)
        #expect(presets.light == 15)
        presets.setSeconds(5_000, for: .failure)
        #expect(presets.failure == 900)
    }
}

@Suite("Workout totals")
struct WorkoutSummaryTests {
    @Test func countsSetsVolumeAndExercises() {
        let t = Fixture.now
        let sets = [
            LoggedSet(intensity: .light, completedAt: t, plannedRestSeconds: 90, exercise: "Squat", weight: 135, reps: 10),
            LoggedSet(intensity: .heavy, completedAt: t, plannedRestSeconds: 180, exercise: "squat", weight: 225, reps: 3),
            LoggedSet(intensity: .failure, completedAt: t, plannedRestSeconds: 240, exercise: "Pull-ups"),
            LoggedSet(intensity: .heavy, completedAt: t, plannedRestSeconds: 180)
        ]
        let summary = WorkoutSummary(sets: sets, startedAt: t, endedAt: t.addingTimeInterval(3_600))
        #expect(summary.totalSets == 4)
        #expect(summary.count(for: .heavy) == 2)
        #expect(summary.count(for: .light) == 1)
        #expect(summary.totalVolume == 135 * 10 + 225 * 3)
        #expect(summary.exercises == ["Squat", "Pull-ups"])
        #expect(summary.duration == 3_600)
    }
}

@Suite("Small helpers")
struct HelperTests {
    @Test func clockFormatting() {
        #expect(Clock.format(90) == "1:30")
        #expect(Clock.format(0) == "0:00")
        #expect(Clock.format(59.2) == "1:00")
        #expect(Clock.format(3_725) == "1:02:05")
    }

    @Test func timeOfDayLabels() {
        #expect(TimeOfDay(hour: 0, minute: 5).label == "12:05 AM")
        #expect(TimeOfDay(hour: 13, minute: 30).label == "1:30 PM")
        #expect(TimeOfDay(hour: 12).label == "12:00 PM")
    }

    @Test func leadTimeLabels() {
        #expect(LeadTime(amount: 1, unit: .days).label == "1 day before")
        #expect(LeadTime(amount: 3, unit: .hours).label == "3 hours before")
    }

    @Test func repeatSummary() {
        #expect(RepeatRule.never.summary == "Doesn't repeat")
        #expect(RepeatRule(frequency: .weekly, interval: 2, weekdays: [5, 2]).summary == "Every 2 weeks on Mon, Thu")
        #expect(RepeatRule(frequency: .daily).summary == "Every day")
    }

    @Test func stableIDsAreDeterministic() {
        let a = StableID.uuid(from: "reminder.123.due")
        #expect(a == StableID.uuid(from: "reminder.123.due"))
        #expect(a != StableID.uuid(from: "reminder.124.due"))
        #expect(a.uuidString.dropFirst(14).first == "5")
    }
}
