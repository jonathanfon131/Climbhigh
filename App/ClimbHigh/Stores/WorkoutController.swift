import ClimbHighCore
import Foundation
import Observation
import SwiftData

/// Runs workout mode: the session, the set log and the rest timer.
///
/// How a set works:
/// 1. Finish a set → tap Light / Heavy / Failure → `finishSet(_:)` logs it and
///    starts that rest.
/// 2. Use your phone freely. When the rest ends, the phone rings/vibrates
///    (AlarmKit alarm or Buzz notifications) until you tap **Start set**.
/// 3. `startNextSet()` silences everything. Repeat.
///
/// The running rest is saved to disk, so closing the app mid-rest is fine.
@MainActor
@Observable
final class WorkoutController {
    struct SetDetails: Equatable {
        var exercise = ""
        var weight: Double?
        var reps: Int?
    }

    private(set) var session: WorkoutSession?
    private(set) var rest: RestPeriod?
    /// True once the rest has run out and we're waiting for you to start the set.
    private(set) var isRestOver = false
    /// The workout that just ended, for the summary screen.
    private(set) var finishedSession: WorkoutSession?
    /// Short message when something fell back (e.g. alarms not allowed).
    var notice: String?

    /// Set by the app when it moves between foreground and background.
    var isAppActive = true {
        didSet { updateInAppVibration() }
    }

    private let context: ModelContext
    private let settings: SettingsStore
    private let alarms: AlarmService
    private let notifications: NotificationService
    private let haptics: HapticsService
    private let focus: FocusService
    private let defaults: UserDefaults

    /// Whether the current rest is using an AlarmKit alarm (vs. Buzz notifications).
    private var restUsesAlarm = false
    private var restEndTask: Task<Void, Never>?
    private var alarmWatchTask: Task<Void, Never>?
    private static let stateKey = "climbhigh.workout.active.v1"

    init(context: ModelContext, settings: SettingsStore, alarms: AlarmService, notifications: NotificationService,
         haptics: HapticsService, focus: FocusService, defaults: UserDefaults = .standard) {
        self.context = context
        self.settings = settings
        self.alarms = alarms
        self.notifications = notifications
        self.haptics = haptics
        self.focus = focus
        self.defaults = defaults
        restoreSavedState()
        watchAlarmChanges()
    }

    var isActive: Bool { session != nil }
    var setCount: Int { session?.sets.count ?? 0 }

    // MARK: Session

    func startSession() {
        guard session == nil else { return }
        let newSession = WorkoutSession()
        context.insert(newSession)
        save()
        session = newSession
        persistState()
        if settings.settings.focusAutomationEnabled {
            focus.runShortcut(named: settings.settings.focusOnShortcutName)
        }
        Task {
            await notifications.requestAuthorization()
            if settings.settings.restAlertStyle == .alarm { await alarms.requestAuthorization() }
        }
    }

    func endSession() {
        guard let current = session else { return }
        endRest()
        current.endedAt = .now
        save()
        session = nil
        finishedSession = current.sets.isEmpty ? nil : current
        if current.sets.isEmpty { context.delete(current); save() }
        persistState()
        if settings.settings.focusAutomationEnabled {
            focus.runShortcut(named: settings.settings.focusOffShortcutName)
        }
    }

    func dismissSummary() {
        finishedSession = nil
    }

    // MARK: Sets and rest

    /// Logs the set you just finished and starts its rest timer.
    func finishSet(_ intensity: SetIntensity, details: SetDetails = SetDetails()) {
        if session == nil { startSession() }
        guard let session else { return }
        endRest()

        let seconds = settings.settings.restPresets.seconds(for: intensity)
        let entry = WorkoutSetEntry(logged: LoggedSet(
            intensity: intensity,
            completedAt: .now,
            plannedRestSeconds: seconds,
            exercise: details.exercise.trimmingCharacters(in: .whitespaces),
            weight: details.weight,
            reps: details.reps
        ))
        context.insert(entry)
        entry.session = session
        save()

        startRest(RestPeriod(intensity: intensity, startedAt: .now, duration: TimeInterval(seconds)))
    }

    /// +15 / −15 seconds. AlarmKit timers can't be edited, so the alarm is
    /// replaced with a new one for the new remaining time.
    func adjustRest(by seconds: Int) {
        guard let current = rest, !isRestOver else { return }
        var adjusted = current
        adjusted.adjust(by: TimeInterval(seconds), now: .now)
        stopAlerts(for: current)
        startRest(RestPeriod(intensity: adjusted.intensity, startedAt: adjusted.startedAt, duration: adjusted.duration))
    }

    /// You're starting the next set: stop the timer, alarm and vibration.
    func startNextSet() {
        guard rest != nil else { return }
        endRest()
        haptics.success()
    }

    /// Called by the alarm's Start set / Stop buttons (see StartNextSetIntent).
    func handleAlarmStopped(restID: UUID?) {
        guard let rest, restID == nil || restID == rest.id else { return }
        startNextSet()
    }

    // MARK: Private — rest lifecycle

    private func startRest(_ period: RestPeriod) {
        rest = period
        isRestOver = false
        persistState()
        scheduleAlerts(for: period)
        scheduleInAppEnd(for: period)
    }

    private func endRest() {
        restEndTask?.cancel()
        restEndTask = nil
        if let rest { stopAlerts(for: rest) }
        haptics.stop()
        rest = nil
        isRestOver = false
        persistState()
    }

    private func stopAlerts(for period: RestPeriod) {
        alarms.stopAndRemove(id: period.id)
        Task { await notifications.cancelRestBuzz() }
    }

    /// Alarm style → AlarmKit timer; if alarms aren't allowed or fail, Buzz notifications.
    private func scheduleAlerts(for period: RestPeriod) {
        let preferences = settings.settings
        Task {
            var usedAlarm = false
            if preferences.restAlertStyle == .alarm {
                if await alarms.requestAuthorization() {
                    do {
                        try await alarms.startRestTimer(id: period.id, seconds: period.remaining(at: .now), intensity: period.intensity)
                        usedAlarm = true
                    } catch {
                        Log.workout.error("Rest alarm failed: \(error.localizedDescription, privacy: .public)")
                        notice = "The alarm couldn't start, so Buzz notifications are used for this rest."
                    }
                } else {
                    notice = "Alarms are off for Climb High, so Buzz notifications are used. Turn on Alarms in iPhone Settings → Climb High."
                }
            }
            if !usedAlarm {
                await notifications.scheduleRestBuzz(
                    restID: period.id, intensity: period.intensity, endsAt: period.endsAt,
                    everySeconds: preferences.buzzEverySeconds, count: preferences.buzzCount
                )
            }
            // If you tapped Start set while this was being scheduled, undo it.
            guard rest?.id == period.id else {
                stopAlerts(for: period)
                return
            }
            restUsesAlarm = usedAlarm
            persistState()
        }
    }

    /// Flips the screen to "Rest's up" when the time runs out while the app is open.
    private func scheduleInAppEnd(for period: RestPeriod) {
        restEndTask?.cancel()
        restEndTask = Task { [weak self] in
            let wait = period.remaining(at: .now)
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled, let self, self.rest?.id == period.id else { return }
            self.isRestOver = true
            self.updateInAppVibration()
        }
    }

    /// In Buzz mode the app vibrates itself while open (an alarm already does).
    private func updateInAppVibration() {
        let shouldVibrate = isRestOver && isAppActive && !restUsesAlarm && settings.settings.vibrateInApp
        if shouldVibrate { haptics.startAlertLoop() } else { haptics.stop() }
    }

    /// If you stop the alarm from the Lock Screen, AlarmKit removes it — treat
    /// that as "starting the next set".
    private func watchAlarmChanges() {
        alarmWatchTask = Task { [weak self] in
            guard let updates = self?.alarms.updates else { return }
            for await current in updates {
                guard let self, let rest = self.rest, self.restUsesAlarm else { continue }
                let stillThere = current.contains { $0.id == rest.id }
                if !stillThere, rest.isFinished(at: .now.addingTimeInterval(1)) {
                    self.startNextSet()
                }
            }
        }
    }

    // MARK: Private — saving

    private struct SavedState: Codable {
        var sessionID: UUID?
        var rest: RestPeriod?
        var restUsesAlarm: Bool
    }

    private func persistState() {
        let state = SavedState(sessionID: session?.id, rest: rest, restUsesAlarm: restUsesAlarm)
        defaults.set(try? JSONCoding.encode(state), forKey: Self.stateKey)
    }

    private func restoreSavedState() {
        guard let data = defaults.data(forKey: Self.stateKey),
              let state = try? JSONCoding.decode(SavedState.self, from: data),
              let sessionID = state.sessionID
        else { return }

        var descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == sessionID })
        descriptor.fetchLimit = 1
        guard let saved = try? context.fetch(descriptor).first, saved.endedAt == nil else { return }
        session = saved
        restUsesAlarm = state.restUsesAlarm

        if let savedRest = state.rest {
            rest = savedRest
            if savedRest.isFinished(at: .now) {
                isRestOver = true
            } else {
                scheduleInAppEnd(for: savedRest)
            }
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            Log.workout.error("Saving workout failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
