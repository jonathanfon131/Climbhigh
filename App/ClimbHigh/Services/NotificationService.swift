import ClimbHighCore
import Foundation
import UserNotifications

/// Everything to do with regular notifications (banners).
///
/// iOS keeps at most 64 scheduled notifications per app, so the budget is split:
/// 42 reminders + 7 daily verses + up to 15 rest-timer buzzes = 64.
@MainActor
final class NotificationService {
    enum Budget {
        static let reminders = 42
        static let verses = 7
    }

    enum Category {
        static let reminder = "REMINDER"
        static let rest = "REST"
        static let verse = "VERSE"
    }

    enum Action {
        static let markDone = "MARK_DONE"
        static let snooze = "SNOOZE_10"
        static let startSet = "START_SET"
        static let markVerseRead = "MARK_VERSE_READ"
    }

    /// Prefixes keep each kind of notification separate so replacing one kind
    /// never deletes another.
    enum Prefix {
        static let reminder = "reminder."
        static let snooze = "snooze."
        static let rest = "rest."
        static let verse = "verse."
    }

    /// Keys stored in each notification's `userInfo`.
    enum InfoKey {
        static let reminderID = "reminderID"
        static let occurrence = "occurrence"
    }

    private let center = UNUserNotificationCenter.current()

    // MARK: Setup

    func registerCategories() {
        let reminder = UNNotificationCategory(
            identifier: Category.reminder,
            actions: [
                UNNotificationAction(identifier: Action.markDone, title: "Done", options: []),
                UNNotificationAction(identifier: Action.snooze, title: "Snooze 10 min", options: [])
            ],
            intentIdentifiers: []
        )
        let rest = UNNotificationCategory(
            identifier: Category.rest,
            actions: [UNNotificationAction(identifier: Action.startSet, title: "Start set", options: [])],
            intentIdentifiers: []
        )
        let verse = UNNotificationCategory(
            identifier: Category.verse,
            actions: [UNNotificationAction(identifier: Action.markVerseRead, title: "I read it", options: [])],
            intentIdentifiers: []
        )
        center.setNotificationCategories([reminder, rest, verse])
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func isAuthorized() async -> Bool {
        let status = await center.notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }

    // MARK: Reminders

    /// Replaces every scheduled reminder notification with `alerts`.
    func replaceReminderAlerts(_ alerts: [PlannedAlert], titles: [UUID: String], calendar: Calendar = .current) async {
        await removePending(withPrefix: Prefix.reminder)
        for alert in alerts.prefix(Budget.reminders) {
            let title = titles[alert.reminderID] ?? "Reminder"
            let content = Self.content(for: alert, title: title)
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: alert.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            await add(UNNotificationRequest(identifier: alert.identifier, content: content, trigger: trigger))
        }
    }

    func scheduleSnooze(reminderID: UUID, title: String, occurrence: Date, minutes: Int = 10) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "Snoozed reminder."
        content.sound = .default
        content.categoryIdentifier = Category.reminder
        content.interruptionLevel = .timeSensitive
        content.userInfo = [InfoKey.reminderID: reminderID.uuidString, InfoKey.occurrence: occurrence.timeIntervalSince1970]
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
        await add(UNNotificationRequest(identifier: Prefix.snooze + UUID().uuidString, content: content, trigger: trigger))
    }

    /// Clears banners already shown for a reminder (after it's marked done).
    func clearDelivered(for reminderID: UUID) async {
        let delivered = await center.deliveredNotifications()
        let ids = delivered
            .filter { ($0.request.content.userInfo[InfoKey.reminderID] as? String) == reminderID.uuidString }
            .map(\.request.identifier)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    private static func content(for alert: PlannedAlert, title: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let due = alert.occurrence.formatted(date: .abbreviated, time: .shortened)
        switch alert.kind {
        case .headsUp:
            content.title = "Coming up: \(title)"
            content.body = "In \(alert.leadTime?.lengthLabel ?? "a bit") · \(due)"
            content.interruptionLevel = .active
        case .due:
            content.title = title
            content.body = "It's time. Tap Done when it's handled."
            content.interruptionLevel = .timeSensitive
        case .nudge:
            content.title = "Today: \(title)"
            content.body = alert.fireDate < alert.occurrence
                ? "Due at \(alert.occurrence.formatted(date: .omitted, time: .shortened))."
                : "Still to do. Tap Done when it's handled."
            content.interruptionLevel = .timeSensitive
        }
        content.sound = .default
        content.categoryIdentifier = Category.reminder
        content.threadIdentifier = alert.reminderID.uuidString
        content.userInfo = [
            InfoKey.reminderID: alert.reminderID.uuidString,
            InfoKey.occurrence: alert.occurrence.timeIntervalSince1970
        ]
        return content
    }

    // MARK: Daily verse

    /// One morning notification per upcoming day, each showing that day's verse.
    func replaceVerseReminders(_ items: [(fireDate: Date, verse: DailyVerse, streak: Int)], calendar: Calendar = .current) async {
        await removePending(withPrefix: Prefix.verse)
        for item in items.prefix(Budget.verses) {
            let content = UNMutableNotificationContent()
            content.title = "Verse of the day · \(item.verse.reference)"
            content.body = item.verse.text
            if item.streak > 0 {
                content.subtitle = "Keep your \(item.streak)-day streak going"
            }
            content.sound = .default
            content.categoryIdentifier = Category.verse
            content.threadIdentifier = "verse"
            let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            let id = Prefix.verse + DayStamp(item.fireDate, calendar: calendar).description
            await add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    // MARK: Rest timer "buzz" mode

    /// Schedules a burst of notifications starting when the rest ends, so the
    /// phone keeps buzzing until you start your set (or the burst runs out).
    func scheduleRestBuzz(restID: UUID, intensity: SetIntensity, endsAt: Date, everySeconds: Int, count: Int) async {
        await cancelRestBuzz()
        let firstDelay = max(1, endsAt.timeIntervalSinceNow)
        for index in 0..<count {
            let content = UNMutableNotificationContent()
            content.title = index == 0 ? "Rest's up — \(intensity.title) set" : "Time to lift"
            content.body = "Tap Start set when you're under the bar."
            content.sound = .default
            content.categoryIdentifier = Category.rest
            content.interruptionLevel = .timeSensitive
            content.threadIdentifier = "rest"
            let delay = firstDelay + TimeInterval(index * everySeconds)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
            await add(UNNotificationRequest(identifier: "\(Prefix.rest)\(restID.uuidString).\(index)", content: content, trigger: trigger))
        }
    }

    func cancelRestBuzz() async {
        await removePending(withPrefix: Prefix.rest)
        let delivered = await center.deliveredNotifications()
        center.removeDeliveredNotifications(withIdentifiers: delivered.map(\.request.identifier).filter { $0.hasPrefix(Prefix.rest) })
    }

    // MARK: Helpers

    private func removePending(withPrefix prefix: String) async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
    }

    private func add(_ request: UNNotificationRequest) async {
        do {
            try await center.add(request)
        } catch {
            Log.alerts.error("Couldn't schedule \(request.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
