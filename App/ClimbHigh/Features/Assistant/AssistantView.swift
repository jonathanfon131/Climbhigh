import ClimbHighCore
import SwiftUI

/// Chat with the on-device assistant. Tap the mic and speak, or type.
struct AssistantView: View {
    @Environment(AssistantController.self) private var assistant
    @Environment(SpeechService.self) private var speech
    @State private var input = ""
    @State private var speechError: String?
    @FocusState private var inputFocused: Bool

    private let suggestions = [
        "Remind me to call Mom tomorrow at 5pm",
        "Note: ideas for the lawn care flyer",
        "Start heavy set",
        "What's coming up?"
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        BigTitle(text: "Assistant", eyebrow: assistant.aiStatus.isReady ? "On-device AI · private" : "Voice commands")
                            .padding(.bottom, 4)

                        if !assistant.aiStatus.isReady {
                            NoticeBanner(text: assistant.aiStatus.message)
                        }

                        if assistant.messages.isEmpty {
                            suggestionList
                        }

                        ForEach(assistant.messages) { message in
                            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                                ChatBubble(text: message.text, fromUser: message.role == .user)
                                ForEach(message.actions) { action in
                                    ActionChip(action: action, isUndone: assistant.undoneActionIDs.contains(action.id)) {
                                        assistant.undo(action)
                                    }
                                }
                            }
                            .id(message.id)
                        }

                        if assistant.isThinking {
                            TypingIndicator()
                        }
                        if let speechError {
                            NoticeBanner(text: speechError, systemImage: "mic.slash.fill", color: Palette.coral)
                        }
                    }
                    .padding(Metrics.screenPadding)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: assistant.messages.count) {
                    guard let lastID = assistant.messages.last?.id else { return }
                    withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
                }
            }

            ChatInputBar(
                text: Binding(
                    get: { speech.isListening ? speech.transcript : input },
                    set: { input = $0 }
                ),
                placeholder: speech.isListening ? "Listening…" : "Ask, or tell me what to remember",
                isBusy: assistant.isThinking,
                focused: $inputFocused,
                isListening: speech.isListening,
                onMic: toggleListening,
                onSend: send
            )
        }
        .screenBackground()
        .toolbar {
            if !assistant.messages.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { assistant.clear() }
                }
            }
        }
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try saying")
                .font(.headline)
                .foregroundStyle(Palette.textSecondary)
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    input = suggestion
                    send()
                } label: {
                    HStack {
                        Text("“\(suggestion)”")
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(14)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func send() {
        let text = input
        input = ""
        inputFocused = false
        Task { await assistant.send(text) }
    }

    private func toggleListening() {
        speechError = nil
        if speech.isListening {
            input = speech.stop()
            send()
        } else {
            Task {
                do {
                    try await speech.start()
                } catch {
                    speechError = error.localizedDescription
                }
            }
        }
    }
}

/// "Reminder created · Tue 5:00 PM  [Undo]"
private struct ActionChip: View {
    let action: AssistantController.Action
    let isUndone: Bool
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(isUndone ? "Undone" : label)
                .strikethrough(isUndone)
                .lineLimit(2)
            if !isUndone {
                Button("Undo", action: onUndo)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .frame(minHeight: 32)
                    .background(Palette.ink.opacity(0.12), in: Capsule())
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color, in: Capsule())
    }

    private var icon: String {
        switch action {
        case .reminder: "bell.fill"
        case .note: "note.text"
        case .rest: "timer"
        }
    }

    private var color: Color {
        switch action {
        case .reminder: Palette.sky
        case .note: Palette.lilac
        case let .rest(intensity): intensity.color
        }
    }

    private var label: String {
        switch action {
        case let .reminder(_, title, due): "\(title) · \(AssistantController.describe(due))"
        case let .note(_, title): "Note saved: \(title)"
        case let .rest(intensity): "\(intensity.title) rest started"
        }
    }
}
