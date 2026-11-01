import BackgroundTasks
import ClimbHighCore
import Foundation
import SwiftData
import SwiftUI

/// The composition root: builds every store and service once and wires them
/// together. Nothing else creates services, so the dependency graph lives in
/// this one file.
///
///   Screens ──read──▶ SwiftData (@Query)
///   Screens ──write─▶ Stores ──▶ Services ──▶ iOS (alarms, notifications, AI, speech)
///                       │
///                       └──▶ ClimbHighCore (pure logic)
@MainActor
final class AppContainer {
    /// Shared instance — also used by Siri/alarm intents, which run outside SwiftUI.
    static let shared = AppContainer()

    static let backgroundRefreshID = "com.jonathanfon.climbhigh.refresh"

    let modelContainer: ModelContainer
    /// Set when the database couldn't be opened (shown in Settings).
    let storageWarning: String?

    // Services (talk to iOS)
    let notifications = NotificationService()
    let alarms = AlarmService()
    let haptics = HapticsService()
    let focus = FocusService()
    let speech = SpeechService()
    let noteAI = NoteAIService()

    // Stores (own the data and the rules for changing it)
    let settings: SettingsStore
    let reminders: ReminderStore
    let notes: NoteStore
    let faith: FaithStore
    let workout: WorkoutController
    let assistant: AssistantController
    let backup: BackupService

    private init() {
        let database = Database.open()
        modelContainer = database.container
        storageWarning = database.warning
        let context = database.container.mainContext

        settings = SettingsStore()
        let scheduler = ReminderAlertScheduler(notifications: notifications, alarms: alarms)
        reminders = ReminderStore(context: context, scheduler: scheduler, notifications: notifications)
        notes = NoteStore(context: context)
        faith = FaithStore(context: context, settings: settings, notifications: notifications)
        workout = WorkoutController(context: context, settings: settings, alarms: alarms,
                                    notifications: notifications, haptics: haptics, focus: focus)
        assistant = AssistantController(reminders: reminders, notes: notes, workout: workout, settings: settings)
        backup = BackupService(context: context, settings: settings, faith: faith)
    }

    // MARK: App lifecycle

    func didLaunch() {
        notifications.registerCategories()
        faith.refreshReminders()
    }

    func scenePhaseChanged(to phase: ScenePhase) {
        workout.isAppActive = phase == .active
        switch phase {
        case .active:
            reminders.refreshAlerts()
            faith.refreshDay()
            faith.refreshReminders()
        case .background:
            scheduleBackgroundRefresh()
        default:
            break
        }
    }

    /// Asks iOS to wake the app occasionally to top up reminder alerts
    /// (iOS only keeps 64 notifications scheduled per app).
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundRefreshID)
        request.earliestBeginDate = Date.now.addingTimeInterval(6 * 3_600)
        try? BGTaskScheduler.shared.submit(request)
    }

    func refreshInBackground() async {
        await reminders.refreshAlertsAndWait()
        faith.refreshReminders()
        scheduleBackgroundRefresh()
    }

    // MARK: Links and notification taps

    func handle(url: URL) {
        // climbhigh://workout?focus=failed comes back from the Focus shortcut.
        if url.host == "workout", url.query?.contains("focus=failed") == true {
            workout.notice = "The Focus shortcut didn't run. Check its name in Settings → Focus."
        }
    }

    /// Whether to show a banner while the app is open.
    func shouldPresentInForeground(identifier: String) -> Bool {
        // In Buzz mode the open app vibrates by itself — no duplicate banners.
        if identifier.hasPrefix(NotificationService.Prefix.rest) {
            return !settings.settings.vibrateInApp
        }
        return true
    }

    func handleNotification(action: String, identifier: String, reminderID: UUID?, occurrence: Date?) {
        if identifier.hasPrefix(NotificationService.Prefix.rest) {
            workout.startNextSet()
            return
        }
        if identifier.hasPrefix(NotificationService.Prefix.verse) {
            if action == NotificationService.Action.markVerseRead { faith.markTodayRead() }
            return
        }
        guard let reminderID else { return }
        switch action {
        case NotificationService.Action.markDone:
            reminders.markDone(reminderID: reminderID, occurrence: occurrence)
        case NotificationService.Action.snooze:
            reminders.snooze(reminderID: reminderID, occurrence: occurrence ?? .now)
        default:
            break // Tapping the banner just opens the app.
        }
    }
}
