import ClimbHighCore
import SwiftUI

/// Chat with Pip, the on-device assistant. Tap the mic and speak, or type.
struct AssistantView: View {
    @Environment(AssistantController.self) private var assistant
    @Environment(SpeechService.self) private var speech
    @State private var input = ""
    @State private var speechError: String?
    @State private var celebrating = false
    @FocusState private var inputFocused: Bool

    /// Pip's face follows what's happening.
    private var pipMood: PipMood {
        if speech.isListening { return .listening }
        if assistant.isThinking { return .thinking }
        if celebrating { return .happy }
        return assistant.aiStatus.isReady ? .idle : .sleepy
    }

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
                        PipHeader(mood: pipMood, isReady: assistant.aiStatus.isReady)
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
                    guard let last = assistant.messages.last else { return }
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    if last.role == .assistant, !last.actions.isEmpty { celebrate() }
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

    /// Pip does a happy bounce for a couple of seconds after doing something for you.
    private func celebrate() {
        celebrating = true
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            celebrating = false
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

/// Big Pip + greeting at the top of the chat.
private struct PipHeader: View {
    let mood: PipMood
    let isReady: Bool

    var body: some View {
        HStack(spacing: 14) {
            PipView(mood: mood, size: 64)
                .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 4) {
                Text("Hi, I'm Pip.")
                    .font(.system(.largeTitle, weight: .heavy))
                    .foregroundStyle(Palette.textPrimary)
                Text(statusLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: mood)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var statusLine: String {
        switch mood {
        case .listening: "Listening…"
        case .thinking: "Thinking…"
        case .happy: "Done!"
        case .sleepy: "Napping — voice commands still work"
        case .idle: isReady ? "Your private, on-device helper" : "Voice commands ready"
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
