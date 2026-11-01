import ClimbHighCore
import Foundation
import SwiftData

// The database tables. SwiftData stores these on the iPhone only.
//
// Rule of thumb: these classes hold data, not logic. Scheduling, parsing and
// math live in ClimbHighCore; screens and stores convert to/from the plain
// `ReminderSnapshot`, `LoggedSet`, … types when they need logic.

@Model
final class Reminder {
    @Attribute(.unique) var id: UUID
    var title: String
    var details: String
    var createdAt: Date
    /// One-time reminders are archived once done; they stay in "Done".
    var isArchived: Bool
    /// `ReminderSchedule` as JSON. Use `schedule` instead of touching this.
    var scheduleData: Data
    /// `[Date]` of finished occurrences, as JSON. Use `completedOccurrences`.
    var completedData: Data

    init(id: UUID = UUID(), title: String, details: String = "", schedule: ReminderSchedule, createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.details = details
        self.createdAt = createdAt
        self.isArchived = false
        self.scheduleData = (try? JSONCoding.encode(schedule)) ?? Data()
        self.completedData = (try? JSONCoding.encode([Date]())) ?? Data()
    }

    var schedule: ReminderSchedule {
        get { (try? JSONCoding.decode(ReminderSchedule.self, from: scheduleData)) ?? ReminderSchedule(firstDue: createdAt) }
        set { if let data = try? JSONCoding.encode(newValue) { scheduleData = data } }
    }

    var completedOccurrences: Set<Date> {
        get { Set((try? JSONCoding.decode([Date].self, from: completedData)) ?? []) }
        set { if let data = try? JSONCoding.encode(newValue.sorted()) { completedData = data } }
    }

    /// Plain copy for the planner / agenda logic.
    var snapshot: ReminderSnapshot {
        ReminderSnapshot(id: id, title: title, schedule: schedule, completedOccurrences: completedOccurrences, isArchived: isArchived)
    }
}

@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    /// Earlier versions, saved before every AI edit so it can be undone.
    @Relationship(deleteRule: .cascade, inverse: \NoteRevision.note)
    var revisions: [NoteRevision] = []

    init(id: UUID = UUID(), title: String = "", content: String = "", createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isPinned = false
    }

    /// Title, or the first line of the note if the title is empty.
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = content.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        return firstLine.isEmpty ? "Untitled note" : firstLine
    }
}

@Model
final class NoteRevision {
    @Attribute(.unique) var id: UUID
    var content: String
    /// Why it was saved, e.g. "Before AI edit".
    var reason: String
    var createdAt: Date
    var note: Note?

    init(id: UUID = UUID(), content: String, reason: String, createdAt: Date = .now) {
        self.id = id
        self.content = content
        self.reason = reason
        self.createdAt = createdAt
    }
}

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSetEntry.session)
    var sets: [WorkoutSetEntry] = []

    init(id: UUID = UUID(), startedAt: Date = .now) {
        self.id = id
        self.startedAt = startedAt
    }

    var orderedSets: [WorkoutSetEntry] { sets.sorted { $0.completedAt < $1.completedAt } }

    var summary: WorkoutSummary {
        WorkoutSummary(sets: orderedSets.map(\.logged), startedAt: startedAt, endedAt: endedAt ?? .now)
    }
}

@Model
final class WorkoutSetEntry {
    @Attribute(.unique) var id: UUID
    var intensityRaw: String
    var completedAt: Date
    var plannedRestSeconds: Int
    var exercise: String
    var weight: Double?
    var reps: Int?
    var session: WorkoutSession?

    init(id: UUID = UUID(), logged: LoggedSet) {
        self.id = id
        self.intensityRaw = logged.intensity.rawValue
        self.completedAt = logged.completedAt
        self.plannedRestSeconds = logged.plannedRestSeconds
        self.exercise = logged.exercise
        self.weight = logged.weight
        self.reps = logged.reps
    }

    var intensity: SetIntensity { SetIntensity(rawValue: intensityRaw) ?? .light }

    var logged: LoggedSet {
        LoggedSet(intensity: intensity, completedAt: completedAt, plannedRestSeconds: plannedRestSeconds, exercise: exercise, weight: weight, reps: reps)
    }
}

/// One day the daily verse was read. The streak is computed from these.
@Model
final class VerseRead {
    /// "2026-11-01" — one row per day.
    @Attribute(.unique) var day: String
    var readAt: Date

    init(day: String, readAt: Date = .now) {
        self.day = day
        self.readAt = readAt
    }
}
