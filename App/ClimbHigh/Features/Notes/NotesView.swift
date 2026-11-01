import SwiftData
import SwiftUI

/// All notes as colorful cards (pinned first). Search, add, swipe to delete.
struct NotesView: View {
    @Environment(NoteStore.self) private var store
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @State private var search = ""
    @State private var newNote: Note?

    private var visible: [Note] {
        let filtered = search.isEmpty ? notes : notes.filter {
            $0.title.localizedCaseInsensitiveContains(search) || $0.content.localizedCaseInsensitiveContains(search)
        }
        return filtered.filter(\.isPinned) + filtered.filter { !$0.isPinned }
    }

    private let accents = [Palette.volt, Palette.coral, Palette.sky, Palette.lilac]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                BigTitle(text: "Notes", eyebrow: "\(notes.count) saved")
                if visible.isEmpty {
                    EmptyStateView(
                        systemImage: "note.text",
                        title: search.isEmpty ? "No notes yet" : "No matches",
                        message: search.isEmpty ? "Tap + to write one, or say “Note: …” to the Assistant. Then tap Review for the AI's take." : "Try a different word."
                    )
                }
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, note in
                    NavigationLink(value: note) {
                        NoteCard(note: note, accent: accents[index % accents.count])
                    }
                    .buttonStyle(PressableStyle())
                    .contextMenu {
                        Button(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin") {
                            store.togglePin(note)
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            store.delete(note)
                        }
                    }
                }
            }
            .padding(Metrics.screenPadding)
        }
        .screenBackground()
        .searchable(text: $search, prompt: "Search notes")
        .navigationDestination(for: Note.self) { note in
            NoteEditorView(note: note)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    newNote = store.create()
                } label: {
                    Image(systemName: "square.and.pencil")
                        .accessibilityLabel("New note")
                }
            }
        }
        .navigationDestination(item: $newNote) { note in
            NoteEditorView(note: note, startEditing: true)
        }
    }
}

private struct NoteCard: View {
    let note: Note
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(note.displayTitle)
                    .font(.title3.weight(.heavy))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                if note.isPinned {
                    Image(systemName: "pin.fill").accessibilityLabel("Pinned")
                }
            }
            if !note.content.isEmpty {
                Text(note.content)
                    .font(.subheadline)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .opacity(0.8)
            }
            Text(note.updatedAt.formatted(.relative(presentation: .named)))
                .font(.caption.weight(.semibold))
                .opacity(0.6)
        }
        .foregroundStyle(Palette.ink)
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
    }
}
