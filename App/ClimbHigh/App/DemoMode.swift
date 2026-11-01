import ClimbHighCore
import Foundation

/// Preview mode used ONLY for screenshots (launch argument `-demo`).
///
/// It runs on a temporary in-memory database filled with sample data and
/// never asks for permissions or schedules real alerts, so CI can capture
/// clean screens. Normal launches never touch this.
enum DemoMode {
    static let isOn = ProcessInfo.processInfo.arguments.contains("-demo")

    /// `-tab workout` opens that tab first.
    static var initialTab: AppTab {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-tab"), index + 1 < args.count else { return .today }
        switch args[index + 1] {
        case "reminders": return .reminders
        case "workout": return .workout
        case "notes": return .notes
        case "pip": return .assistant
        default: return .today
        }
    }

    @MainActor
    static func seed(_ container: AppContainer) {
        let calendar = Calendar.current
        let now = Date.now
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: now) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? now
        }
        let defaults = container.settings.settings
        func schedule(_ due: Date, _ rule: RepeatRule = .never) -> ReminderSchedule {
            ReminderSchedule(firstDue: due, repeatRule: rule, leadTimes: defaults.defaultLeadTimes,
                             ringsAlarm: true, dayOfNudges: defaults.defaultNudgeTimes)
        }

        container.reminders.create(title: "Call Mom", schedule: schedule(at(0, 17)))
        container.reminders.create(title: "Send lawn-care quotes", schedule: schedule(at(1, 9)))
        container.reminders.create(title: "Pay truck insurance", schedule: schedule(at(3, 10), RepeatRule(frequency: .monthly)))
        container.reminders.create(title: "Gym — legs", schedule: schedule(at(1, 6, 30), RepeatRule(frequency: .weekly, weekdays: [2, 4, 6])))

        container.notes.create(title: "Lawn care side business", content: """
            Target: 20 weekly clients in Pace by spring.
            Price around $45 a cut, upsell edging and leaf cleanup.
            Flyers at HOA boards, Nextdoor posts, ask neighbors for referrals.
            Need: trailer, second mower, insurance.
            """)
        container.notes.create(title: "Workout plan", content: "Mon legs, Wed push, Fri pull. Add 5 lb each week on squat.")

        let readDays = (1...6).compactMap { calendar.date(byAdding: .day, value: -$0, to: now) }
            .map { DayStamp($0, calendar: calendar).description }
        container.faith.importReadDays(readDays)

        container.workout.startSession()
        container.workout.finishSet(.light)
        container.workout.finishSet(.heavy)

        container.assistant.seedDemoConversation()
    }
}
