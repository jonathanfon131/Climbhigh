import ClimbHighCore
import Foundation
import Observation
import SwiftUI

/// Holds `AppSettings` and saves every change to UserDefaults as JSON.
@MainActor
@Observable
final class SettingsStore {
    private(set) var settings: AppSettings
    private let defaults: UserDefaults
    private static let key = "climbhigh.settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONCoding.decode(AppSettings.self, from: data) {
            settings = saved
        } else {
            settings = AppSettings()
        }
    }

    func update(_ change: (inout AppSettings) -> Void) {
        change(&settings)
        save()
    }

    func replace(with newSettings: AppSettings) {
        settings = newSettings
        save()
    }

    /// A SwiftUI binding to one setting, e.g. `settings.binding(\.vibrateInApp)`.
    func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.settings[keyPath: keyPath] },
            set: { newValue in self.update { $0[keyPath: keyPath] = newValue } }
        )
    }

    private func save() {
        guard let data = try? JSONCoding.encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
