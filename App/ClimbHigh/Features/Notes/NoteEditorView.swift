import SwiftData
import SwiftUI

/// Write a note. The bottom bar opens the AI: **Review** (opinion, fixes,
/// ideas, improved version you can approve) and **Discuss** (chat about it
/// and turn the chat into a plan).
struct NoteEditorView: View {
    @Bindable private var note: Note
    private let startEditing: Bool

    @Environment(NoteStore.self) private var store
    @FocusState private var focus: Field?
    @State private var sheet: Sheet?
    @State private var confirmDelete = false
    @State private var isDeleted = false

    private enum Field { case title, content }

    enum Sheet: String, Identifiable {
        case review, discuss, history
        var id: String { rawValue }
    }

    init(note: Note, startEditing: Bool = false) {
        _note = Bindable(note)
        self.startEditing = startEditing
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Title", text: $note.title, axis: .vertical)
                    .font(.system(.largeTitle, weight: .heavy))
                    .foregroundStyle(Palette.textPrimary)
                    .focused($focus, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focus = .content }

                Text("Edited \(note.updatedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)

                TextEditor(text: $note.content)
                    .font(.body)
                    .foregroundStyle(Palette.textPrimary)
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(true)
                    .frame(minHeight: 360, alignment: .topLeading)
                    .focused($focus, equals: .content)
                    .overlay(alignment: .topLeading) {
                        if note.content.isEmpty {
                            Text("Start typing… ideas, plans, anything.")
                                .foregroundStyle(Palette.textSecondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .padding(Metrics.screenPadding)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { aiBar }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin") { store.togglePin(note) }
                    Button("History", systemImage: "clock.arrow.circlepath") { sheet = .history }
                    ShareLink(item: "\(note.displayTitle)\n\n\(note.content)")
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("More")
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }
            }
        }
        .confirmationDialog("Delete this note?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                isDeleted = true
                store.delete(note)
            }
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .review: NoteReviewSheet(note: note) { sheet = .discuss }
            case .discuss: NoteDiscussionView(note: note)
            case .history: NoteHistoryView(note: note)
            }
        }
        .onChange(of: note.content) { note.updatedAt = .now }
        .onChange(of: note.title) { note.updatedAt = .now }
        .onAppear { if startEditing { focus = .title } }
        .onDisappear(perform: saveOrDiscard)
    }

    private var aiBar: some View {
        HStack(spacing: 10) {
            Button {
                focus = nil
                sheet = .review
            } label: {
                Label("Review", systemImage: "sparkles")
            }
            .buttonStyle(.pill)
            Button {
                focus = nil
                sheet = .discuss
            } label: {
                Label("Discuss", systemImage: "bubble.left.and.bubble.right.fill")
            }
            .buttonStyle(.pillSecondary)
        }
        .disabled(note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 10)
        .background(.bar)
    }

    /// Saves on the way out; an untouched empty note is removed instead.
    private func saveOrDiscard() {
        guard !isDeleted else { return }
        let isEmpty = note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isEmpty {
            store.delete(note)
        } else {
            store.touch(note)
        }
    }
}

/// Earlier versions of a note, saved before each AI edit. Tap Restore to go back.
struct NoteHistoryView: View {
    let note: Note
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if note.revisions.isEmpty {
                    Text("No earlier versions yet. One is saved automatically every time you approve an AI edit.")
                        .foregroundStyle(Palette.textSecondary)
                }
                ForEach(note.revisions.sorted { $0.createdAt > $1.createdAt }) { revision in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(revision.reason).font(.headline)
                            Spacer()
                            Text(revision.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        Text(revision.content)
                            .font(.subheadline)
                            .lineLimit(5)
                            .foregroundStyle(Palette.textSecondary)
                        Button("Restore this version") {
                            store.restore(note, to: revision)
                            dismiss()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() } }
            }
        }
    }
}
