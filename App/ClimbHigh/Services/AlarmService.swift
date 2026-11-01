import ActivityKit
import AlarmKit
import ClimbHighCore
import Foundation
import SwiftUI

/// Wraps Apple's AlarmKit: real alarms that ring through Silent mode and
/// Focus, with a countdown on the Lock Screen and in the Dynamic Island.
///
/// Used for (1) the rest timer and (2) the "due" moment of reminders that
/// have "Ring as alarm" turned on.
@MainActor
final class AlarmService {
    typealias Configuration = AlarmManager.AlarmConfiguration<ClimbHighAlarmMetadata>

    /// Conservative cap on reminder alarms scheduled at once (the nearest ones win;
    /// later ones are added as the app re-plans).
    static let maxReminderAlarms = 24

    private let manager = AlarmManager.shared
    private let defaults: UserDefaults
    private static let reminderAlarmIDsKey = "climbhigh.alarms.reminderIDs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Permission

    var isAuthorized: Bool { manager.authorizationState == .authorized }

    /// Asks once; afterwards returns the saved answer.
    @discardableResult
    func requestAuthorization() async -> Bool {
        switch manager.authorizationState {
        case .authorized: return true
        case .denied: return false
        default:
            let state = try? await manager.requestAuthorization()
            return state == .authorized
        }
    }

    /// Emits the app's current alarms whenever they change (e.g. you tapped
    /// Stop on the Lock Screen while the app was closed).
    var updates: some AsyncSequence<[Alarm], Never> { manager.alarmUpdates }

    // MARK: Rest timer

    func startRestTimer(id: UUID, seconds: TimeInterval, intensity: SetIntensity) async throws {
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: "Rest's up — \(intensity.title.lowercased()) set"),
            secondaryButton: AlarmButton(text: "Start set", textColor: SharedPalette.ink, systemImageName: "figure.strengthtraining.traditional"),
            secondaryButtonBehavior: .custom
        )
        let countdown = AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: "\(intensity.title) rest"),
            pauseButton: nil
        )
        let attributes = AlarmAttributes<ClimbHighAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert, countdown: countdown, paused: nil),
            metadata: ClimbHighAlarmMetadata(kind: .rest, title: "\(intensity.title) rest", subtitle: "Next set when this hits zero"),
            tintColor: SharedPalette.volt
        )
        let configuration = Configuration.timer(
            duration: seconds,
            attributes: attributes,
            stopIntent: StartNextSetIntent(restID: id.uuidString),
            secondaryIntent: StartNextSetIntent(restID: id.uuidString),
            sound: .default
        )
        _ = try await manager.schedule(id: id, configuration: configuration)
    }

    /// Stops a ringing or counting alarm and removes it.
    func stopAndRemove(id: UUID) {
        try? manager.stop(id: id)
        try? manager.cancel(id: id)
    }

    // MARK: Reminder alarms

    /// Makes the set of scheduled reminder alarms match `alerts` exactly:
    /// cancels ones no longer wanted, adds new ones, leaves unchanged ones alone.
    func replaceReminderAlarms(_ alerts: [PlannedAlert], titles: [UUID: String]) async {
        let wanted = Array(alerts.prefix(Self.maxReminderAlarms))
        var wantedIDs: [UUID: PlannedAlert] = [:]
        for alert in wanted {
            let title = titles[alert.reminderID] ?? "Reminder"
            wantedIDs[StableID.uuid(from: alert.identifier + "|" + title)] = alert
        }

        let previouslyScheduled = savedReminderAlarmIDs()
        for id in previouslyScheduled where wantedIDs[id] == nil {
            try? manager.cancel(id: id)
        }

        let existing = Set(((try? manager.alarms) ?? []).map(\.id))
        var scheduled = Set<UUID>()
        for (id, alert) in wantedIDs {
            if existing.contains(id) {
                scheduled.insert(id)
                continue
            }
            do {
                try await scheduleReminderAlarm(id: id, alert: alert, title: titles[alert.reminderID] ?? "Reminder")
                scheduled.insert(id)
            } catch {
                Log.alerts.error("Reminder alarm failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        saveReminderAlarmIDs(scheduled)
    }

    private func scheduleReminderAlarm(id: UUID, alert: PlannedAlert, title: String) async throws {
        let ring = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: title),
            secondaryButton: AlarmButton(text: "Snooze 10m", textColor: SharedPalette.ink, systemImageName: "zzz"),
            secondaryButtonBehavior: .countdown
        )
        let snoozed = AlarmPresentation.Countdown(
            title: LocalizedStringResource(stringLiteral: "Snoozed: \(title)"),
            pauseButton: nil
        )
        let attributes = AlarmAttributes<ClimbHighAlarmMetadata>(
            presentation: AlarmPresentation(alert: ring, countdown: snoozed, paused: nil),
            metadata: ClimbHighAlarmMetadata(kind: .reminder, title: title, subtitle: "Snoozed"),
            tintColor: SharedPalette.sky
        )
        let configuration = Configuration(
            countdownDuration: Alarm.CountdownDuration(preAlert: nil, postAlert: 10 * 60),
            schedule: .fixed(alert.fireDate),
            attributes: attributes,
            stopIntent: nil,
            secondaryIntent: nil,
            sound: .default
        )
        _ = try await manager.schedule(id: id, configuration: configuration)
    }

    private func savedReminderAlarmIDs() -> Set<UUID> {
        Set((defaults.stringArray(forKey: Self.reminderAlarmIDsKey) ?? []).compactMap(UUID.init(uuidString:)))
    }

    private func saveReminderAlarmIDs(_ ids: Set<UUID>) {
        defaults.set(ids.map(\.uuidString), forKey: Self.reminderAlarmIDsKey)
    }
}
