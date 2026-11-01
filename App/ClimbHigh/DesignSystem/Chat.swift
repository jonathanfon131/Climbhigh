import SwiftUI

/// One chat message. Yours are lime on the right; Pip's are on the left with a little avatar.
struct ChatBubble: View {
    let text: String
    let fromUser: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if fromUser {
                Spacer(minLength: 48)
            } else {
                PipView(mood: .idle, size: 24, animated: false)
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(.body)
                .foregroundStyle(fromUser ? Palette.ink : Palette.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    fromUser ? Palette.volt : Palette.surface,
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if !fromUser { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(fromUser ? "You: \(text)" : "Pip: \(text)")
    }
}

/// Pip thinking, shown while the on-device AI works.
struct TypingIndicator: View {
    var label = "Pip is thinking…"

    var body: some View {
        HStack(spacing: 8) {
            PipView(mood: .thinking, size: 30)
                .frame(width: 48, height: 48)
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

/// Text field + send button (+ optional mic) pinned to the bottom of chats.
struct ChatInputBar: View {
    @Binding var text: String
    let placeholder: String
    var isBusy = false
    var focused: FocusState<Bool>.Binding
    var isListening = false
    var onMic: (() -> Void)?
    let onSend: () -> Void

    private var canSend: Bool {
        !isBusy && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...5)
                .font(.body) // 17 pt — no zoom-on-focus, comfortable to read
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .focused(focused)
                .submitLabel(.send)
                .onSubmit { if canSend { onSend() } }

            if let onMic {
                CircleIconButton(
                    systemImage: isListening ? "stop.fill" : "mic.fill",
                    label: isListening ? "Stop listening" : "Speak",
                    fill: isListening ? Palette.coral : Palette.lilac,
                    foreground: Palette.ink,
                    action: onMic
                )
            }

            CircleIconButton(
                systemImage: "arrow.up",
                label: "Send",
                fill: canSend ? Palette.volt : Palette.surfaceRaised,
                foreground: canSend ? Palette.ink : Palette.textSecondary
            ) {
                if canSend { onSend() }
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, Metrics.screenPadding)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
