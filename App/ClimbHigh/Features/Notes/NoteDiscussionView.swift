import SwiftUI

/// Chat with the AI about one note, then turn the conversation into a plan.
/// The plan is only added to the note when you tap **Add to note**.
struct NoteDiscussionView: View {
    let note: Note

    @Environment(NoteAIService.self) private var ai
    @Environment(NoteStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var discussion: NoteDiscussion?
    @State private var input = ""
    @State private var plan: NotePlan?
    @State private var planError: String?
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if let discussion {
                    chat(discussion)
                } else {
                    VStack(spacing: 16) {
                        NoticeBanner(text: ai.status.message, systemImage: "exclamationmark.triangle.fill", color: Palette.coral)
                        Spacer()
                    }
                    .padding(Metrics.screenPadding)
                }
            }
            .screenBackground()
            .navigationTitle(note.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                if let discussion, discussion.messages.count > 1 {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Make plan") { Task { await makePlan(discussion) } }
                            .disabled(discussion.isThinking)
                    }
                }
            }
            .sheet(item: $plan) { plan in
                PlanPreview(plan: plan) {
                    store.appendPlan(note, title: plan.title, steps: plan.steps)
                    self.plan = nil
                    dismiss()
                }
                .presentationDetents([.medium, .large])
            }
        }
        .onAppear {
            if discussion == nil, ai.status.isReady {
                discussion = ai.startDiscussion(title: note.displayTitle, content: note.content)
            }
        }
    }

    private func chat(_ discussion: NoteDiscussion) -> some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(discussion.messages) { message in
                            ChatBubble(text: message.text, fromUser: message.fromUser)
                                .id(message.id)
                        }
                        if discussion.isThinking {
                            TypingIndicator()
                        }
                        if let error = discussion.errorText ?? planError {
                            NoticeBanner(text: error, systemImage: "exclamationmark.triangle.fill", color: Palette.coral)
                        }
                    }
                    .padding(Metrics.screenPadding)
                }
                .onChange(of: discussion.messages.count) {
                    guard let lastID = discussion.messages.last?.id else { return }
                    withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                }
            }
            ChatInputBar(text: $input, placeholder: "Ask about this note…", isBusy: discussion.isThinking, focused: $inputFocused) {
                let text = input
                input = ""
                Task { await discussion.send(text) }
            }
        }
    }

    private func makePlan(_ discussion: NoteDiscussion) async {
        planError = nil
        do {
            plan = try await discussion.makePlan()
        } catch {
            planError = AIErrorText.describe(error)
        }
    }
}

extension NotePlan: Identifiable {
    var id: String { title + steps.joined() }
}

private struct PlanPreview: View {
    let plan: NotePlan
    let onApprove: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(plan.title)
                        .font(.title.weight(.heavy))
                    ForEach(Array(plan.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundStyle(Palette.ink)
                                .frame(width: 30, height: 30)
                                .background(Palette.volt, in: Circle())
                            Text(step)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .foregroundStyle(Palette.textPrimary)
                .padding(Metrics.screenPadding)
            }
            .screenBackground()
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Discard") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Add to note", action: onApprove)
                    .buttonStyle(.pill)
                    .padding(Metrics.screenPadding)
                    .background(.bar)
            }
        }
    }
}
