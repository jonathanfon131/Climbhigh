import ClimbHighCore
import Foundation
import Observation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Export everything to one JSON file and import it back.
///
/// Import merges by ID: items already on the phone are updated, new ones added,
/// nothing is deleted. So importing the same backup twice is harmless.
@MainActor
@Observable
final class BackupService {
    struct ImportResult {
        let reminders: Int
        let notes: Int
        let workouts: Int
        let verseDays: Int

        var summary: String {
            "Restored \(reminders) reminders, \(notes) notes, \(workouts) workouts and \(verseDays) verse days."
        }
    }

    private let context: ModelContext
    private let settings: SettingsStore
    private let faith: FaithStore

    init(context: ModelContext, settings: SettingsStore, faith: FaithStore) {
        self.context = context
        self.settings = settings
        self.faith = faith
    }

    func makeBackup() throws -> BackupFile {
        let reminders = (try? context.fetch(FetchDescriptor<Reminder>())) ?? []
        let notes = (try? context.fetch(FetchDescriptor<Note>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []

        let document = BackupDocument(
            exportedAt: .now,
            settings: settings.settings,
            reminders: reminders.map {
                ReminderRecord(id: $0.id, title: $0.title, details: $0.details, createdAt: $0.createdAt,
                               schedule: $0.schedule, completedOccurrences: Array($0.completedOccurrences), isArchived: $0.isArchived)
            },
            notes: notes.map {
                NoteRecord(id: $0.id, title: $0.title, content: $0.content, createdAt: $0.createdAt, updatedAt: $0.updatedAt, isPinned: $0.isPinned)
            },
            workouts: sessions.map {
                WorkoutRecord(id: $0.id, startedAt: $0.startedAt, endedAt: $0.endedAt, sets: $0.orderedSets.map(\.logged))
            },
            verseDays: faith.readDays.map(\.description)
        )
        return BackupFile(data: try document.encoded())
    }

    func restore(from data: Data) throws -> ImportResult {
        let document = try BackupDocument.decode(data)
        settings.replace(with: document.settings)

        let existingReminders = Dictionary(uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Reminder>())) ?? []).map { ($0.id, $0) })
        for record in document.reminders {
            let reminder = existingReminders[record.id] ?? {
                let created = Reminder(id: record.id, title: record.title, schedule: record.schedule, createdAt: record.createdAt)
                context.insert(created)
                return created
            }()
            reminder.title = record.title
            reminder.details = record.details
            reminder.schedule = record.schedule
            reminder.completedOccurrences = Set(record.completedOccurrences)
            reminder.isArchived = record.isArchived
        }

        let existingNotes = Dictionary(uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Note>())) ?? []).map { ($0.id, $0) })
        for record in document.notes {
            let note = existingNotes[record.id] ?? {
                let created = Note(id: record.id, createdAt: record.createdAt)
                context.insert(created)
                return created
            }()
            note.title = record.title
            note.content = record.content
            note.updatedAt = record.updatedAt
            note.isPinned = record.isPinned
        }

        let existingSessions = Set(((try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []).map(\.id))
        var addedWorkouts = 0
        for record in document.workouts where !existingSessions.contains(record.id) {
            let session = WorkoutSession(id: record.id, startedAt: record.startedAt)
            session.endedAt = record.endedAt ?? record.sets.last?.completedAt ?? record.startedAt
            context.insert(session)
            for logged in record.sets {
                let entry = WorkoutSetEntry(logged: logged)
                context.insert(entry)
                entry.session = session
            }
            addedWorkouts += 1
        }

        try context.save()
        faith.importReadDays(document.verseDays)
        return ImportResult(reminders: document.reminders.count, notes: document.notes.count,
                            workouts: addedWorkouts, verseDays: document.verseDays.count)
    }

    static func suggestedFileName(date: Date = .now) -> String {
        "ClimbHigh-Backup-\(date.formatted(.iso8601.year().month().day()))"
    }
}

/// Wraps backup data so SwiftUI's file exporter/importer can save it to Files.
struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
