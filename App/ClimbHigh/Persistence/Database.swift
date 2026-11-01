import Foundation
import OSLog
import SwiftData

/// Opens the on-device database.
///
/// If the database file can't be opened (very rare — e.g. a corrupted file),
/// the app still launches with a temporary in-memory database and shows a
/// warning in Settings, instead of crashing. Export a backup from Settings
/// regularly so nothing is ever lost.
enum Database {
    static let schema = Schema([
        Reminder.self,
        Note.self,
        NoteRevision.self,
        WorkoutSession.self,
        WorkoutSetEntry.self,
        VerseRead.self
    ])

    struct Opened {
        let container: ModelContainer
        /// Non-nil when we fell back to memory-only storage.
        let warning: String?
    }

    static func open() -> Opened {
        if DemoMode.isOn {
            // Screenshot preview: throwaway data that never touches the real database.
            // swiftlint:disable:next force_try
            let memory = try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
            return Opened(container: memory, warning: nil)
        }
        do {
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema))
            return Opened(container: container, warning: nil)
        } catch {
            Log.app.error("Database failed to open: \(error.localizedDescription, privacy: .public)")
            // swiftlint:disable:next force_try — an in-memory store cannot fail to open.
            let memory = try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
            return Opened(
                container: memory,
                warning: "Your saved data couldn't be opened, so changes right now won't be kept. Restore from a backup in Settings."
            )
        }
    }
}

/// One logger per area, visible in Console.app when debugging.
enum Log {
    static let app = Logger(subsystem: "com.jonathanfon.climbhigh", category: "app")
    static let alerts = Logger(subsystem: "com.jonathanfon.climbhigh", category: "alerts")
    static let workout = Logger(subsystem: "com.jonathanfon.climbhigh", category: "workout")
    static let ai = Logger(subsystem: "com.jonathanfon.climbhigh", category: "ai")
    static let faith = Logger(subsystem: "com.jonathanfon.climbhigh", category: "faith")
}
