import ClimbHighCore
import Foundation
import FoundationModels
import Observation

/// Pip, the assistant tab: type or speak.
///
/// Every message goes through two layers:
/// 1. `CommandParser` (ClimbHighCore) — instant, offline, no AI. Handles
///    "remind me…", "note…", "start heavy set", "what's coming up".
/// 2. Apple's on-device model — for everything else (questions, chat), with
///    tools so it can also create reminders and notes when you ask in your own words.
@MainActor
@Observable
final class AssistantController {
    struct Message: Identifiable, Equatable {
        enum Role { case user, assistant }
        let id = UUID()
        let role: Role
        let text: String
        var actions: [Action] = []
    }

    /// Something the assistant did, shown as a chip with Undo.
    enum Action: Equatable, Identifiable {
        case reminder(id: UUID, title: String, due: Date)
        case note(id: UUID, title: String)
        case rest(SetIntensity)

        var id: String {
            switch self {
            case let .reminder(id, _, _): "r-\(id)"
            case let .note(id, _): "n-\(id)"
            case let .rest(intensity): "w-\(intensity.rawValue)"
            }
        }
    }

    private(set) var messages: [Message] = []
    private(set) var isThinking = false
    private(set) var undoneActionIDs: Set<String> = []

    private let reminders: ReminderStore
    private let notes: NoteStore
    private let workout: WorkoutController
    private let settings: SettingsStore

    /// When you ask for a reminder without a time, we remember the title and ask "when?".
    private var reminderWaitingForTime: String?
    private var aiSession: LanguageModelSession?
    private var actionsFromTools: [Action] = []

    init(reminders: ReminderStore, notes: NoteStore, workout: WorkoutController, settings: SettingsStore) {
        self.reminders = reminders
        self.notes = notes
        self.workout = workout
        self.settings = settings
    }

    var aiStatus: AIStatus { AIStatus.current }

    // MARK: Conversation

    func send(_ raw: String) async {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        messages.append(Message(role: .user, text: text))

        if let title = reminderWaitingForTime {
            reminderWaitingForTime = nil
            if let match = dateParser.parse(text, now: .now) {
                let action = createReminder(title: title, due: match.date)
                reply("Done — I'll remind you: \(title), \(Self.describe(match.date)).", actions: [action])
                return
            }
        }

        switch CommandParser(dates: dateParser).parse(text, now: .now) {
        case let .createReminder(title, due?):
            let action = createReminder(title: title, due: due)
            reply("Done — I'll remind you: \(title), \(Self.describe(due)).", actions: [action])

        case let .createReminder(title, nil):
            reminderWaitingForTime = title
            reply("When should I remind you about “\(title)”? Say something like “tomorrow at 9” or “in 2 hours”.")

        case let .createNote(body):
            let action = createNote(title: "", content: body)
            reply("Saved to Notes. Open it and tap Review if you want my take on it.", actions: [action])

        case let .startRest(intensity):
            workout.finishSet(intensity)
            reply("\(intensity.title) set logged. Resting \(Clock.format(TimeInterval(settings.settings.restPresets.seconds(for: intensity)))) — I'll get you when it's time.", actions: [.rest(intensity)])

        case .listUpcoming:
            reply(upcomingSummary(limit: 5))

        case .unrecognized:
            await askAI(text)
        }
    }

    func clear() {
        messages = []
        aiSession = nil
        reminderWaitingForTime = nil
        undoneActionIDs = []
    }

    func undo(_ action: Action) {
        guard !undoneActionIDs.contains(action.id) else { return }
        switch action {
        case let .reminder(id, _, _):
            if let reminder = reminders.reminder(id: id) { reminders.delete(reminder) }
        case let .note(id, _):
            if let note = notes.note(id: id) { notes.delete(note) }
        case .rest:
            workout.startNextSet()
        }
        undoneActionIDs.insert(action.id)
    }

    /// Sample chat for screenshots (DemoMode only).
    func seedDemoConversation() {
        messages = [
            Message(role: .user, text: "Remind me to send the lawn quotes tomorrow at 9"),
            Message(role: .assistant, text: "Done — I'll remind you: Send the lawn quotes, tomorrow at 9:00 AM.",
                    actions: [.reminder(id: UUID(), title: "Send the lawn quotes",
                                        due: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0,
                                                                  of: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now) ?? .now)]),
            Message(role: .user, text: "What's coming up?"),
            Message(role: .assistant, text: upcomingSummary(limit: 3))
        ]
    }

    // MARK: AI

    private func askAI(_ text: String) async {
        guard aiStatus.isReady else {
            reply("""
                \(aiStatus.message)

                Things I can always do:
                • “Remind me to call Mom tomorrow at 5pm”
                • “Note: new pricing idea…”
                • “Start heavy set”
                • “What's coming up?”
                """)
            return
        }

        isThinking = true
        defer { isThinking = false }
        actionsFromTools = []
        let session = aiSession ?? makeSession()
        aiSession = session
        do {
            let answer = try await session.respond(to: text).content
            reply(answer, actions: actionsFromTools)
        } catch let error as LanguageModelSession.GenerationError {
            if case .exceededContextWindowSize = error {
                aiSession = nil // start fresh next time
                reply("This chat got long, so I've started a fresh one. Ask me again?")
            } else {
                reply(AIErrorText.describe(error))
            }
        } catch {
            reply(AIErrorText.describe(error))
        }
    }

    private func makeSession() -> LanguageModelSession {
        let now = Date.now.formatted(date: .complete, time: .shortened)
        return LanguageModelSession(
            tools: [CreateReminderTool(assistant: self), CreateNoteTool(assistant: self)],
            instructions: """
                You are Pip, a cheerful, warm and direct little helper inside the user's personal iPhone app \
                Climb High, for reminders, notes, workouts and a daily Bible verse. It is now \(now). \
                Answer in 1 to 3 short sentences unless asked for more. \
                When the user wants to be reminded of something, call createReminder. \
                When the user wants something saved or written down, call createNote. \
                Never claim you created something unless a tool confirmed it.

                The user's upcoming reminders:
                \(upcomingSummary(limit: 8))
                """
        )
    }

    // MARK: Called by the AI tools

    func toolCreateReminder(title: String, when: String) -> String {
        guard let match = dateParser.parse(when, now: .now) else {
            return "Could not understand the time “\(when)”. Ask the user for a specific day and time."
        }
        let action = createReminder(title: CommandParser.cleanTitle(title), due: match.date)
        actionsFromTools.append(action)
        return "Created reminder “\(title)” for \(Self.describe(match.date))."
    }

    func toolCreateNote(title: String, content: String) -> String {
        actionsFromTools.append(createNote(title: title, content: content))
        return "Saved note “\(title.isEmpty ? "Untitled" : title)”."
    }

    // MARK: Helpers

    private var dateParser: DatePhraseParser {
        DatePhraseParser(calendar: reminders.calendar)
    }

    private func reply(_ text: String, actions: [Action] = []) {
        messages.append(Message(role: .assistant, text: text, actions: actions))
    }

    private func createReminder(title: String, due: Date) -> Action {
        let defaults = settings.settings
        let schedule = ReminderSchedule(
            firstDue: due,
            leadTimes: defaults.defaultLeadTimes.map { LeadTime(amount: $0.amount, unit: $0.unit) },
            ringsAlarm: defaults.defaultRingsAlarm,
            dayOfNudges: defaults.defaultNudgeTimes
        )
        let reminder = reminders.create(title: title, schedule: schedule)
        return .reminder(id: reminder.id, title: reminder.title, due: due)
    }

    private func createNote(title: String, content: String) -> Action {
        let note = notes.create(title: title, content: content)
        return .note(id: note.id, title: note.displayTitle)
    }

    private func upcomingSummary(limit: Int) -> String {
        let open = reminders.agenda().filter { $0.entry.section != .done }.prefix(limit)
        guard !open.isEmpty else { return "Nothing coming up. Enjoy it." }
        return open.map { item in
            "• \(item.reminder.title) — \(item.entry.occurrence.map(Self.describe) ?? "")"
        }.joined(separator: "\n")
    }

    static func describe(_ date: Date) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return "today at \(time)" }
        if calendar.isDateInTomorrow(date) { return "tomorrow at \(time)" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) + " at \(time)"
    }
}

// MARK: - Tools the on-device model can call

struct CreateReminderTool: Tool {
    let name = "createReminder"
    let description = "Creates a reminder that alerts the user at a specific time."

    @Generable
    struct Arguments {
        @Guide(description: "What to be reminded about, short, e.g. 'Call Mom' or 'Pay rent'.")
        var title: String
        @Guide(description: "When, in plain words, e.g. 'tomorrow at 5pm', 'friday at 9am', 'in 2 hours'.")
        var when: String
    }

    let assistant: AssistantController

    func call(arguments: Arguments) async throws -> String {
        await assistant.toolCreateReminder(title: arguments.title, when: arguments.when)
    }
}

struct CreateNoteTool: Tool {
    let name = "createNote"
    let description = "Saves a note in the user's Notes."

    @Generable
    struct Arguments {
        @Guide(description: "A short title for the note.")
        var title: String
        @Guide(description: "The full text of the note.")
        var content: String
    }

    let assistant: AssistantController

    func call(arguments: Arguments) async throws -> String {
        await assistant.toolCreateNote(title: arguments.title, content: arguments.content)
    }
}
