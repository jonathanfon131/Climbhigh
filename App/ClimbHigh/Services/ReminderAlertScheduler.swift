import ClimbHighCore
import Foundation

/// Turns the saved reminders into real alerts on the phone.
///
/// Flow: reminders → `AlertPlanner` (pure logic, unit-tested) → split into
/// alarms (due time, "Ring as alarm" on) and notifications (everything else)
/// → handed to AlarmService / NotificationService.
///
/// It always rebuilds the whole plan, so calling it extra times is harmless.
/// It runs when reminders change, when the app opens, and in background refresh.
@MainActor
final class ReminderAlertScheduler {
    private let notifications: NotificationService
    private let alarms: AlarmService
    private let planner: AlertPlanner
    private var currentRun: Task<Void, Never>?

    /// How far ahead to schedule. Further alerts are added on later runs.
    static let horizonDays = 30

    init(notifications: NotificationService, alarms: AlarmService, calendar: Calendar = .current) {
        self.notifications = notifications
        self.alarms = alarms
        self.planner = AlertPlanner(calendar: calendar)
    }

    /// Starts a re-plan (cancelling one already in progress).
    func reschedule(_ reminders: [ReminderSnapshot]) {
        currentRun?.cancel()
        currentRun = Task { await apply(reminders, now: .now) }
    }

    /// Same as `reschedule` but waits until finished (used by background refresh).
    func rescheduleAndWait(_ reminders: [ReminderSnapshot]) async {
        currentRun?.cancel()
        await apply(reminders, now: .now)
    }

    private func apply(_ reminders: [ReminderSnapshot], now: Date) async {
        let plan = planner.plan(for: reminders, now: now, horizonDays: Self.horizonDays)
        let titles = Dictionary(uniqueKeysWithValues: reminders.map { ($0.id, $0.title) })
        let ringing = Set(reminders.filter(\.schedule.ringsAlarm).map(\.id))
        var canRing = alarms.isAuthorized
        if !canRing, !ringing.isEmpty {
            canRing = await alarms.requestAuthorization()
        }

        var alarmAlerts: [PlannedAlert] = []
        var notificationAlerts: [PlannedAlert] = []
        for alert in plan {
            let wantsAlarm = alert.kind == .due && ringing.contains(alert.reminderID)
            if wantsAlarm, canRing, alarmAlerts.count < AlarmService.maxReminderAlarms {
                alarmAlerts.append(alert)
            } else {
                notificationAlerts.append(alert)
            }
        }

        guard !Task.isCancelled else { return }
        await notifications.replaceReminderAlerts(notificationAlerts, titles: titles)
        guard !Task.isCancelled else { return }
        await alarms.replaceReminderAlarms(alarmAlerts, titles: titles)
        Log.alerts.info("Planned \(alarmAlerts.count) alarms and \(min(notificationAlerts.count, NotificationService.Budget.reminders)) notifications")
    }
}
