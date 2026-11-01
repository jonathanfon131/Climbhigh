import SwiftUI

/// The AI's review of a note: its opinion, what to fix, what to add, next
/// moves and questions — plus an improved version. Nothing changes until you
/// tap **Approve & apply** (and the old text is kept in History).
struct NoteReviewSheet: View {
    let note: Note
    /// Opens the discussion chat (to answer the AI's questions).
    var onDiscuss: () -> Void = {}

    @Environment(NoteAIService.self) private var ai
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .loading
    @State private var showImproved = false

    enum Phase {
        case loading
        case unavailable(String)
        case failed(String)
        case ready(NoteReview)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch phase {
                    case .loading:
                        loading
                    case let .unavailable(message), let .failed(message):
                        PipView(mood: .sleepy, size: 56)
                            .frame(maxWidth: .infinity)
                        NoticeBanner(text: message, systemImage: "exclamationmark.triangle.fill", color: Palette.coral)
                        if case .failed = phase {
                            Button("Try again") { Task { await load() } }
                                .buttonStyle(.pillSecondary)
                        }
                    case let .ready(review):
                        reviewContent(review)
                    }
                }
                .padding(Metrics.screenPadding)
            }
            .screenBackground()
            .navigationTitle("Pip's review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) { approveBar }
        }
        .task { await load() }
    }

    private var loading: some View {
        VStack(spacing: 14) {
            PipView(mood: .thinking, size: 72)
                .frame(width: 108, height: 108)
            Text("Pip is reading your note…")
                .font(.headline)
            Text("Runs on your iPhone. Usually takes 5–20 seconds.")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    @ViewBuilder
    private func reviewContent(_ review: NoteReview) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PIP'S TAKE")
                .font(.caption.weight(.heavy))
                .tracking(1.2)
            Text(review.opinion)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Palette.ink)
        .card(color: Palette.volt)

        ReviewList(title: "Fix", systemImage: "wrench.adjustable.fill", items: review.issues, color: Palette.coral)
        ReviewList(title: "Worth adding", systemImage: "plus.square.fill", items: review.additions, color: Palette.sky)
        ReviewList(title: "Next moves", systemImage: "arrow.up.right.circle.fill", items: review.nextSteps, color: Palette.lilac)

        if !review.questions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Questions for you", systemImage: "questionmark.bubble.fill")
                    .font(.headline)
                ForEach(review.questions, id: \.self) { question in
                    Text(question)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Answer these in a chat") {
                    dismiss()
                    onDiscuss()
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Palette.accent)
            }
            .foregroundStyle(Palette.textPrimary)
            .card()
        }

        DisclosureGroup(isExpanded: $showImproved) {
            Text(review.improvedNote)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
        } label: {
            Label("Improved version", systemImage: "doc.text.fill")
                .font(.headline)
                .foregroundStyle(Palette.textPrimary)
        }
        .tint(Palette.accent)
        .card()
    }

    @ViewBuilder
    private var approveBar: some View {
        if case let .ready(review) = phase {
            VStack(spacing: 8) {
                Button("Approve & apply") {
                    store.applyAIEdit(note, newContent: review.improvedNote)
                    dismiss()
                }
                .buttonStyle(.pill)
                Text("Replaces the note with the improved version. The old one is kept in History.")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Metrics.screenPadding)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private func load() async {
        guard ai.status.isReady else {
            phase = .unavailable(ai.status.message)
            return
        }
        phase = .loading
        do {
            phase = .ready(try await ai.review(title: note.title, content: note.content))
        } catch {
            phase = .failed(AIErrorText.describe(error))
        }
    }
}

private struct ReviewList: View {
    let title: String
    let systemImage: String
    let items: [String]
    let color: Color

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .foregroundStyle(Palette.textPrimary)
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Circle().fill(color).frame(width: 8, height: 8)
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(Palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .card()
        }
    }
}
