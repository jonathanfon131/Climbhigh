import AudioToolbox
import Foundation
import UIKit

/// Vibration while the app is open (e.g. "rest's up" in Buzz mode).
@MainActor
final class HapticsService {
    private var loop: Task<Void, Never>?

    var isLooping: Bool { loop != nil }

    /// Vibrates every ~1.2 s until `stop()` is called.
    func startAlertLoop() {
        guard loop == nil else { return }
        loop = Task {
            while !Task.isCancelled {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                try? await Task.sleep(for: .milliseconds(1_200))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    func tap() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

/// Turns Focus (Do Not Disturb) on/off by running two Shortcuts you create
/// once. iOS doesn't let apps flip Focus directly — Shortcuts can, and this is
/// Apple's supported way to connect them. See docs/FOCUS-SETUP.md.
@MainActor
final class FocusService {
    /// Runs a shortcut by name, then iOS returns to Climb High.
    func runShortcut(named name: String) {
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "x-callback-url"
        components.path = "/run-shortcut"
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "x-success", value: "climbhigh://workout"),
            URLQueryItem(name: "x-error", value: "climbhigh://workout?focus=failed")
        ]
        guard let url = components.url else { return }
        UIApplication.shared.open(url)
    }

    func openShortcutsApp() {
        guard let url = URL(string: "shortcuts://") else { return }
        UIApplication.shared.open(url)
    }
}
