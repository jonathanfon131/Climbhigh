import ClimbHighCore
import Foundation
import Observation
import SwiftData

/// Creates, edits and versions notes. Every AI change saves the previous
/// text first, so any AI edit can be undone from the note's History.
@MainActor
@Observable
final class NoteStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func all() -> [Note] {
        let sort = [SortDescriptor(\Note.updatedAt, order: .reverse)]
        return (try? context.fetch(FetchDescriptor<Note>(sortBy: sort))) ?? []
    }

    func note(id: UUID) -> Note? {
        var descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    func create(title: String = "", content: String = "") -> Note {
        let note = Note(title: title, content: content)
        context.insert(note)
        save()
        return note
    }

    /// Call after typing changes (the editor does this automatically).
    func touch(_ note: Note) {
        note.updatedAt = .now
        save()
    }

    func togglePin(_ note: Note) {
        note.isPinned.toggle()
        save()
    }

    /// Replaces the note's text with an approved AI version, keeping the old one.
    func applyAIEdit(_ note: Note, newContent: String) {
        keepRevision(of: note, reason: "Before AI edit")
        note.content = newContent
        note.updatedAt = .now
        save()
    }

    /// Adds an approved plan to the end of the note, keeping the old version.
    func appendPlan(_ note: Note, title: String, steps: [String]) {
        keepRevision(of: note, reason: "Before adding plan")
        let numbered = steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        let block = "\n\n— Plan: \(title) —\n\(numbered)"
        note.content = note.content.trimmingCharacters(in: .whitespacesAndNewlines) + block
        note.updatedAt = .now
        save()
    }

    /// Puts an earlier version back (and keeps the current one, so restore is undoable too).
    func restore(_ note: Note, to revision: NoteRevision) {
        keepRevision(of: note, reason: "Before restore")
        note.content = revision.content
        note.updatedAt = .now
        save()
    }

    func delete(_ note: Note) {
        context.delete(note)
        save()
    }

    func deleteAll() {
        for note in all() { context.delete(note) }
        save()
    }

    private func keepRevision(of note: Note, reason: String) {
        let revision = NoteRevision(content: note.content, reason: reason)
        context.insert(revision)
        revision.note = note
    }

    private func save() {
        do {
            try context.save()
        } catch {
            Log.app.error("Saving notes failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
