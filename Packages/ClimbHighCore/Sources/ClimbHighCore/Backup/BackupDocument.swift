import Foundation

/// The backup file format: one readable JSON file with everything in the app.
///
/// Export it to Files/iCloud Drive before deleting the app or switching phones,
/// then import it to get everything back. `version` lets future app versions
/// read older backups.
public struct BackupDocument: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var exportedAt: Date
    public var settings: AppSettings
    public var reminders: [ReminderRecord]
    public var notes: [NoteRecord]
    public var workouts: [WorkoutRecord]

    public init(exportedAt: Date, settings: AppSettings, reminders: [ReminderRecord], notes: [NoteRecord], workouts: [WorkoutRecord]) {
        self.version = Self.currentVersion
        self.exportedAt = exportedAt
        self.settings = settings
        self.reminders = reminders
        self.notes = notes
        self.workouts = workouts
    }

    public enum BackupError: Error, Equatable, LocalizedError {
        case newerVersion(Int)

        public var errorDescription: String? {
            switch self {
            case let .newerVersion(version):
                "This backup was made by a newer version of Climb High (format \(version)). Update the app first."
            }
        }
    }

    public func encoded() throws -> Data {
        try JSONCoding.encode(self)
    }

    public static func decode(_ data: Data) throws -> BackupDocument {
        let document = try JSONCoding.decode(BackupDocument.self, from: data)
        guard document.version <= currentVersion else { throw BackupError.newerVersion(document.version) }
        return document
    }
}

public struct ReminderRecord: Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var details: String
    public var createdAt: Date
    public var schedule: ReminderSchedule
    public var completedOccurrences: [Date]
    public var isArchived: Bool

    public init(id: UUID, title: String, details: String, createdAt: Date, schedule: ReminderSchedule, completedOccurrences: [Date], isArchived: Bool) {
        self.id = id
        self.title = title
        self.details = details
        self.createdAt = createdAt
        self.schedule = schedule
        self.completedOccurrences = completedOccurrences.sorted()
        self.isArchived = isArchived
    }
}

public struct NoteRecord: Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var content: String
    public var createdAt: Date
    public var updatedAt: Date
    public var isPinned: Bool

    public init(id: UUID, title: String, content: String, createdAt: Date, updatedAt: Date, isPinned: Bool) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
    }
}

public struct WorkoutRecord: Codable, Equatable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var sets: [LoggedSet]

    public init(id: UUID, startedAt: Date, endedAt: Date?, sets: [LoggedSet]) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.sets = sets
    }
}
