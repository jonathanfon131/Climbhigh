import AlarmKit
import SwiftUI
import UIKit
import UserNotifications

/// Shows which permissions are on, with a button to fix each one.
struct PermissionsStatusView: View {
    @State private var notificationsOn: Bool?
    @State private var alarmsOn: Bool?
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            StatusRow(title: "Notifications", isOn: notificationsOn, fix: requestNotifications)
            StatusRow(title: "Alarms", isOn: alarmsOn, fix: requestAlarms)
            StatusRow(title: "On-device AI", isOn: AIStatus.current.isReady, detail: AIStatus.current.isReady ? nil : AIStatus.current.message, fix: openSettings)
            Button("Open iPhone Settings for Climb High", action: openSettings)
        }
        .task { await refresh() }
    }

    private func refresh() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationsOn = status == .authorized || status == .provisional
        alarmsOn = AlarmManager.shared.authorizationState == .authorized
    }

    private func requestNotifications() {
        Task {
            if notificationsOn == false, await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied {
                openSettings()
            } else {
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            }
            await refresh()
        }
    }

    private func requestAlarms() {
        Task {
            if AlarmManager.shared.authorizationState == .denied {
                openSettings()
            } else {
                _ = try? await AlarmManager.shared.requestAuthorization()
            }
            await refresh()
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}

private struct StatusRow: View {
    let title: String
    let isOn: Bool?
    var detail: String?
    let fix: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(Palette.textSecondary)
                }
            }
            Spacer()
            switch isOn {
            case .some(true):
                Label("On", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Palette.accent)
            case .some(false):
                Button("Turn on", action: fix)
                    .buttonStyle(.borderedProminent)
                    .tint(Palette.accent)
            case .none:
                ProgressView()
            }
        }
        .labelStyle(.titleAndIcon)
        .font(.body.weight(.medium))
    }
}
