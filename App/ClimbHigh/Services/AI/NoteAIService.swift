import Foundation
import FoundationModels
import Observation

/// What the AI says about a note. `@Generable` makes the on-device model fill
/// in exactly these fields, so the answer is structured, not free text.
@Generable
struct NoteReview: Equatable {
    @Guide(description: "Your honest opinion of the note in 2 or 3 sentences: what is strong, what is weak, and whether the idea is worth pursuing.")
    var opinion: String

    @Guide(description: "Problems to fix: unclear wording, missing details, contradictions, spelling or grammar mistakes. Empty if there are none.")
    var issues: [String]

    @Guide(description: "Specific things worth adding to make the note more complete or useful.")
    var additions: [String]

    @Guide(description: "Practical next moves the author could take from here.")
    var nextSteps: [String]

    @Guide(description: "Questions to ask the author to understand what the note is for and how to improve it.")
    var questions: [String]

    @Guide(description: "The complete improved note: keep every original idea, fix the mistakes, and organize it clearly with short headings and dashes for lists. Plain text only, no markdown symbols like ** or #.")
    var improvedNote: String
}

/// A plan the AI drafts from a note discussion.
@Generable
struct NotePlan: Equatable {
    @Guide(description: "A short name for the plan, 2 to 6 words.")
    var title: String

    @Guide(description: "Between 3 and 8 concrete steps in the order they should happen. Each step starts with a verb.")
    var steps: [String]
}

/// Note analysis: review + improved version, and a chat to discuss the note.
/// Nothing changes in the note until you tap Approve.
@MainActor
@Observable
final class NoteAIService {
    /// The on-device model has a limited context window; longer notes are trimmed for analysis.
    static let maxCharacters = 6_000

    var status: AIStatus { AIStatus.current }

    func review(title: String, content: String) async throws -> NoteReview {
        let session = LanguageModelSession(instructions: """
            You are a sharp, honest editor and business-minded thinking partner. \
            You review the user's personal notes. Be specific and practical, never generic. \
            Have your own opinion. Keep the user's voice and meaning when you improve the note.
            """)
        let prompt = """
            Review this note.

            Title: \(title.isEmpty ? "(none)" : title)

            Note:
            \(Self.trimmed(content))
            """
        return try await session.respond(to: prompt, generating: NoteReview.self).content
    }

    func startDiscussion(title: String, content: String) -> NoteDiscussion {
        NoteDiscussion(title: title, content: Self.trimmed(content))
    }

    static func trimmed(_ content: String) -> String {
        content.count > maxCharacters ? String(content.prefix(maxCharacters)) + "\n[…note continues]" : content
    }
}

/// A back-and-forth chat about one note. Ends with an optional plan you can add to it.
@MainActor
@Observable
final class NoteDiscussion {
    struct Message: Identifiable, Equatable {
        let id = UUID()
        let fromUser: Bool
        let text: String
    }

    private(set) var messages: [Message]
    private(set) var isThinking = false
    private(set) var errorText: String?
    private let session: LanguageModelSession

    init(title: String, content: String) {
        session = LanguageModelSession(instructions: """
            You are a practical thinking partner helping the user develop one of their notes. \
            Ask clarifying questions, give your honest opinion, and suggest concrete improvements. \
            Keep replies under 120 words.

            The note is titled "\(title)". Its content:
            \(content)
            """)
        messages = [Message(fromUser: false, text: "Pip here! What do you want this note to do for you? Ask me anything about it — or tell me the goal and I'll map out how to get there.")]
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return }
        messages.append(Message(fromUser: true, text: trimmed))
        isThinking = true
        errorText = nil
        defer { isThinking = false }
        do {
            let reply = try await session.respond(to: trimmed).content
            messages.append(Message(fromUser: false, text: reply))
        } catch {
            errorText = AIErrorText.describe(error)
        }
    }

    /// Drafts an action plan from everything discussed so far.
    func makePlan() async throws -> NotePlan {
        isThinking = true
        defer { isThinking = false }
        return try await session.respond(
            to: "Turn the note and everything we discussed into a concrete action plan.",
            generating: NotePlan.self
        ).content
    }
}
