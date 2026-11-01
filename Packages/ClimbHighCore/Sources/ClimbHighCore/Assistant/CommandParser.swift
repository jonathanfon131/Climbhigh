import Foundation

/// What the user asked for, in plain terms.
public enum AssistantCommand: Equatable, Sendable {
    /// `due == nil` means no time was understood — the app should ask for one.
    case createReminder(title: String, due: Date?)
    case createNote(text: String)
    case startRest(SetIntensity)
    case listUpcoming
    /// Not a known command — hand it to the AI (or show help if AI is off).
    case unrecognized
}

/// Understands simple typed or spoken commands without any AI, so the core
/// voice features work instantly, offline, and on every device:
///
/// - "Remind me to call Mom tomorrow at 5pm"
/// - "Set a reminder for Friday at 9 to pay rent"
/// - "Note: try the new pricing page" / "Take a note …"
/// - "Start heavy set" / "Light rest"
/// - "What's coming up?"
public struct CommandParser: Sendable {
    public var dates: DatePhraseParser

    public init(dates: DatePhraseParser) {
        self.dates = dates
    }

    public func parse(_ input: String, now: Date) -> AssistantCommand {
        let text = Self.stripPoliteness(input.trimmingCharacters(in: Self.edgeCharacters))
        guard !text.isEmpty else { return .unrecognized }
        let lower = text.lowercased().replacingOccurrences(of: "’", with: "'")

        if let body = Self.strip(prefixes: Self.reminderPrefixes, from: text) {
            return reminder(from: body, now: now)
        }
        if let range = lower.range(of: "remind me") {
            // "Can you please remind me …" — take everything after "remind me".
            let offset = lower.distance(from: lower.startIndex, to: range.upperBound)
            return reminder(from: String(text.dropFirst(offset)), now: now)
        }
        if let body = Self.strip(prefixes: Self.notePrefixes, from: text) {
            return body.isEmpty ? .unrecognized : .createNote(text: Self.capitalizeFirst(body))
        }
        if let intensity = Self.restIntensity(in: lower) {
            return .startRest(intensity)
        }
        if Self.upcomingPhrases.contains(where: { lower.contains($0) }) {
            return .listUpcoming
        }
        return .unrecognized
    }

    private func reminder(from body: String, now: Date) -> AssistantCommand {
        if let match = dates.parse(body, now: now) {
            return .createReminder(title: Self.cleanTitle(match.remainder), due: match.date)
        }
        return .createReminder(title: Self.cleanTitle(body), due: nil)
    }
}

// MARK: - Vocabulary (longest phrases first)

extension CommandParser {
    static let reminderPrefixes = [
        "set a reminder to", "set a reminder for", "set a reminder", "set reminder",
        "add a reminder to", "add a reminder for", "add a reminder",
        "create a reminder to", "create a reminder",
        "new reminder", "reminder to", "reminder:", "reminder"
    ]

    static let notePrefixes = [
        "take a note that", "take a note", "make a note that", "make a note",
        "add a note that", "add a note", "create a note", "new note",
        "write down that", "write down", "jot down", "note to self", "note that", "note:", "note"
    ]

    static let upcomingPhrases = [
        "what's coming up", "whats coming up", "what is coming up", "what's next", "whats next",
        "what do i have", "my reminders", "upcoming", "what's on my", "whats on my"
    ]

    static let politeOpeners = ["hey ", "ok ", "okay ", "please ", "can you ", "could you ", "would you "]

    static let edgeCharacters = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".!?"))
}

// MARK: - Helpers

extension CommandParser {
    /// "start heavy set", "light rest", "failure timer" → intensity.
    static func restIntensity(in lower: String) -> SetIntensity? {
        let words = Set(lower.split(whereSeparator: { !$0.isLetter }).map(String.init))
        let restWords: Set<String> = ["set", "rest", "timer", "break", "sets"]
        guard !words.isDisjoint(with: restWords) else { return nil }
        return SetIntensity.allCases.first { words.contains($0.rawValue) }
    }

    /// Removes the first matching prefix (only at a word boundary) and returns the rest.
    static func strip(prefixes: [String], from text: String) -> String? {
        let lower = text.lowercased()
        for prefix in prefixes where lower.hasPrefix(prefix) {
            let rest = lower.dropFirst(prefix.count)
            if let next = rest.first, next.isLetter || next.isNumber { continue }
            let body = text.dropFirst(prefix.count)
            return body.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ":,-")))
        }
        return nil
    }

    static func stripPoliteness(_ text: String) -> String {
        var result = text
        var changed = true
        while changed {
            changed = false
            for opener in politeOpeners where result.lowercased().hasPrefix(opener) {
                result = String(result.dropFirst(opener.count))
                changed = true
            }
        }
        return result
    }

    /// "to call Mom" → "Call Mom"
    static func cleanTitle(_ raw: String) -> String {
        var title = raw.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: ",:-")))
        for leading in ["to ", "about ", "that ", "for "] where title.lowercased().hasPrefix(leading) {
            title = String(title.dropFirst(leading.count))
            break
        }
        title = title.trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? "Reminder" : capitalizeFirst(title)
    }

    static func capitalizeFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}
