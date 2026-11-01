import Foundation
import Testing
@testable import ClimbHighCore

@Suite("Saved data and backups")
struct StorageFormatTests {
    @Test func backupRoundTrip() throws {
        let schedule = ReminderSchedule(
            firstDue: Fixture.date(2026, 11, 4, 15),
            repeatRule: RepeatRule(frequency: .weekly, weekdays: [2, 4]),
            leadTimes: [LeadTime(amount: 2, unit: .hours)],
            dayOfNudges: [TimeOfDay(hour: 9)]
        )
        let document = BackupDocument(
            exportedAt: Fixture.now,
            settings: AppSettings(restAlertStyle: .buzz),
            reminders: [ReminderRecord(id: UUID(), title: "Dentist", details: "Bring card", createdAt: Fixture.now, schedule: schedule, completedOccurrences: [Fixture.date(2026, 11, 4, 15)], isArchived: false)],
            notes: [NoteRecord(id: UUID(), title: "Ideas", content: "Lawn plan", createdAt: Fixture.now, updatedAt: Fixture.now, isPinned: true)],
            workouts: [WorkoutRecord(id: UUID(), startedAt: Fixture.now, endedAt: nil, sets: [LoggedSet(intensity: .heavy, completedAt: Fixture.now, plannedRestSeconds: 180)])]
        )
        let decoded = try BackupDocument.decode(try document.encoded())
        #expect(decoded == document)
    }

    @Test func rejectsBackupsFromNewerVersions() throws {
        var document = BackupDocument(exportedAt: Fixture.now, settings: AppSettings(), reminders: [], notes: [], workouts: [])
        document.version = 99
        let data = try document.encoded()
        #expect(throws: BackupDocument.BackupError.newerVersion(99)) {
            try BackupDocument.decode(data)
        }
    }

    @Test func oldSettingsStillLoad() throws {
        let saved = Data(#"{"restAlertStyle":"buzz"}"#.utf8)
        let settings = try JSONCoding.decode(AppSettings.self, from: saved)
        #expect(settings.restAlertStyle == .buzz)
        #expect(settings.restPresets == .evidenceBased)
        #expect(settings.defaultNudgeTimes.count == 3)
    }

    @Test func oldSchedulesStillLoad() throws {
        let saved = Data(#"{"firstDue":"2026-11-04T21:00:00Z"}"#.utf8)
        let schedule = try JSONCoding.decode(ReminderSchedule.self, from: saved)
        #expect(schedule.firstDue == Fixture.date(2026, 11, 4, 15))
        #expect(schedule.repeatRule == .never)
        #expect(schedule.ringsAlarm)
    }
}
