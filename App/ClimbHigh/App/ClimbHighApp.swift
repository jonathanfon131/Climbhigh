import SwiftUI
import UserNotifications

@main
struct ClimbHighApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    private let container = AppContainer.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(container.settings)
                .environment(container.reminders)
                .environment(container.notes)
                .environment(container.workout)
                .environment(container.assistant)
                .environment(container.speech)
                .environment(container.noteAI)
                .environment(container.backup)
                .environment(\.storageWarning, container.storageWarning)
                .environment(\.focusService, container.focus)
                .modelContainer(container.modelContainer)
                .onOpenURL { container.handle(url: $0) }
        }
        .onChange(of: scenePhase) { _, phase in
            container.scenePhaseChanged(to: phase)
        }
        .backgroundTask(.appRefresh(AppContainer.backgroundRefreshID)) {
            await AppContainer.shared.refreshInBackground()
        }
    }
}

/// UIKit hooks SwiftUI doesn't cover: notification taps and action buttons.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        AppContainer.shared.didLaunch()
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let identifier = notification.request.identifier
        let show = await MainActor.run { AppContainer.shared.shouldPresentInForeground(identifier: identifier) }
        return show ? [.banner, .list, .sound] : []
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        let identifier = response.notification.request.identifier
        let info = response.notification.request.content.userInfo
        let reminderID = (info[NotificationService.InfoKey.reminderID] as? String).flatMap(UUID.init(uuidString:))
        let occurrence = (info[NotificationService.InfoKey.occurrence] as? Double).map(Date.init(timeIntervalSince1970:))
        await MainActor.run {
            AppContainer.shared.handleNotification(action: action, identifier: identifier, reminderID: reminderID, occurrence: occurrence)
        }
    }
}

// MARK: - Environment values for non-observable dependencies

extension EnvironmentValues {
    @Entry var storageWarning: String? = nil
    @Entry var focusService: FocusService? = nil
}
