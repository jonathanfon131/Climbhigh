import AppIntents
import ClimbHighCore
import Foundation

/// Runs when you tap **Start set** (or Stop) on the rest alarm — even from the
/// Lock Screen while Climb High is closed. Ends the rest and silences the alarm.
struct StartNextSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start Next Set"
    static let description = IntentDescription("Ends your rest timer and silences the alarm.")

    @Parameter(title: "Rest ID")
    var restID: String

    init() {
        restID = ""
    }

    init(restID: String) {
        self.restID = restID
    }

    func perform() async throws -> some IntentResult {
        let id = UUID(uuidString: restID)
        await MainActor.run {
            AppContainer.shared.workout.handleAlarmStopped(restID: id)
        }
        return .result()
    }
}

/// The set types, for Siri and the Shortcuts app.
enum SetIntensityOption: String, AppEnum {
    case light, heavy, failure

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Set Type"
    static let caseDisplayRepresentations: [SetIntensityOption: DisplayRepresentation] = [
        .light: "Light",
        .heavy: "Heavy",
        .failure: "Failure"
    ]

    var intensity: SetIntensity {
        switch self {
        case .light: .light
        case .heavy: .heavy
        case .failure: .failure
        }
    }
}

/// "Hey Siri, heavy set in Climb High" — logs a set and starts its rest.
/// Also usable from the Action Button or a Shortcut.
struct StartRestIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Rest Timer"
    static let description = IntentDescription("Logs the set you just finished and starts its rest timer.")

    @Parameter(title: "Set Type", default: .heavy)
    var setType: SetIntensityOption

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let intensity = setType.intensity
        let seconds = await MainActor.run { () -> Int in
            let container = AppContainer.shared
            container.workout.finishSet(intensity)
            return container.settings.settings.restPresets.seconds(for: intensity)
        }
        return .result(dialog: "Resting \(Clock.format(TimeInterval(seconds))). I'll get you when it's time.")
    }
}

/// Makes the intents available to Siri and Spotlight without any setup.
struct ClimbHighShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRestIntent(),
            phrases: [
                "Start \(\.$setType) rest in \(.applicationName)",
                "\(\.$setType) set in \(.applicationName)",
                "Start rest in \(.applicationName)"
            ],
            shortTitle: "Rest Timer",
            systemImageName: "timer"
        )
    }
}
