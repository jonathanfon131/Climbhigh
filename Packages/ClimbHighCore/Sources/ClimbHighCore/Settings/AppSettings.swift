import Foundation

/// How the phone gets your attention when a rest ends.
public enum RestAlertStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    /// AlarmKit alarm: rings and vibrates through Silent mode and Focus until you tap it.
    case alarm
    /// A burst of notifications every few seconds. Follows the Silent switch
    /// (vibration only when silenced). Needs Climb High allowed in your Focus.
    case buzz

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .alarm: "Alarm"
        case .buzz: "Buzz"
        }
    }

    public var explanation: String {
        switch self {
        case .alarm: "Rings and vibrates until you tap Start set — even on Silent or in Focus."
        case .buzz: "Repeated notifications. On Silent it only vibrates. Allow Climb High in your Focus."
        }
    }
}

/// Every user preference in one place. Stored as JSON in UserDefaults.
///
/// New fields must have a default and be decoded with `decodeIfPresent`, so
/// older saved settings keep loading after an update.
public struct AppSettings: Codable, Equatable, Sendable {
    // Workout
    public var restPresets: RestPresets
    public var restAlertStyle: RestAlertStyle
    public var buzzEverySeconds: Int
    public var buzzForSeconds: Int
    public var vibrateInApp: Bool

    // Reminder defaults for new reminders
    public var defaultLeadTimes: [LeadTime]
    public var defaultNudgeTimes: [TimeOfDay]
    public var defaultRingsAlarm: Bool

    // Focus / Do Not Disturb automation (via Shortcuts)
    public var focusAutomationEnabled: Bool
    public var focusOnShortcutName: String
    public var focusOffShortcutName: String

    // Daily verse
    public var verseReminderEnabled: Bool
    public var verseReminderTime: TimeOfDay

    public init(
        restPresets: RestPresets = .evidenceBased,
        restAlertStyle: RestAlertStyle = .alarm,
        buzzEverySeconds: Int = 5,
        buzzForSeconds: Int = 60,
        vibrateInApp: Bool = true,
        defaultLeadTimes: [LeadTime] = [LeadTime(amount: 1, unit: .days)],
        defaultNudgeTimes: [TimeOfDay] = [TimeOfDay(hour: 9), TimeOfDay(hour: 13), TimeOfDay(hour: 18)],
        defaultRingsAlarm: Bool = true,
        focusAutomationEnabled: Bool = false,
        focusOnShortcutName: String = "Climb High Focus On",
        focusOffShortcutName: String = "Climb High Focus Off",
        verseReminderEnabled: Bool = true,
        verseReminderTime: TimeOfDay = TimeOfDay(hour: 7)
    ) {
        self.restPresets = restPresets
        self.restAlertStyle = restAlertStyle
        self.buzzEverySeconds = min(max(buzzEverySeconds, 3), 30)
        self.buzzForSeconds = min(max(buzzForSeconds, 15), 180)
        self.vibrateInApp = vibrateInApp
        self.defaultLeadTimes = defaultLeadTimes
        self.defaultNudgeTimes = defaultNudgeTimes.sorted()
        self.defaultRingsAlarm = defaultRingsAlarm
        self.focusAutomationEnabled = focusAutomationEnabled
        self.focusOnShortcutName = focusOnShortcutName
        self.focusOffShortcutName = focusOffShortcutName
        self.verseReminderEnabled = verseReminderEnabled
        self.verseReminderTime = verseReminderTime
    }

    /// How many buzz notifications one rest schedules (iOS allows 64 pending in total).
    public var buzzCount: Int {
        max(1, min(15, buzzForSeconds / max(buzzEverySeconds, 1)))
    }

    private enum CodingKeys: String, CodingKey {
        case restPresets, restAlertStyle, buzzEverySeconds, buzzForSeconds, vibrateInApp
        case defaultLeadTimes, defaultNudgeTimes, defaultRingsAlarm
        case focusAutomationEnabled, focusOnShortcutName, focusOffShortcutName
        case verseReminderEnabled, verseReminderTime
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        self.init(
            restPresets: try c.decodeIfPresent(RestPresets.self, forKey: .restPresets) ?? defaults.restPresets,
            restAlertStyle: try c.decodeIfPresent(RestAlertStyle.self, forKey: .restAlertStyle) ?? defaults.restAlertStyle,
            buzzEverySeconds: try c.decodeIfPresent(Int.self, forKey: .buzzEverySeconds) ?? defaults.buzzEverySeconds,
            buzzForSeconds: try c.decodeIfPresent(Int.self, forKey: .buzzForSeconds) ?? defaults.buzzForSeconds,
            vibrateInApp: try c.decodeIfPresent(Bool.self, forKey: .vibrateInApp) ?? defaults.vibrateInApp,
            defaultLeadTimes: try c.decodeIfPresent([LeadTime].self, forKey: .defaultLeadTimes) ?? defaults.defaultLeadTimes,
            defaultNudgeTimes: try c.decodeIfPresent([TimeOfDay].self, forKey: .defaultNudgeTimes) ?? defaults.defaultNudgeTimes,
            defaultRingsAlarm: try c.decodeIfPresent(Bool.self, forKey: .defaultRingsAlarm) ?? defaults.defaultRingsAlarm,
            focusAutomationEnabled: try c.decodeIfPresent(Bool.self, forKey: .focusAutomationEnabled) ?? defaults.focusAutomationEnabled,
            focusOnShortcutName: try c.decodeIfPresent(String.self, forKey: .focusOnShortcutName) ?? defaults.focusOnShortcutName,
            focusOffShortcutName: try c.decodeIfPresent(String.self, forKey: .focusOffShortcutName) ?? defaults.focusOffShortcutName,
            verseReminderEnabled: try c.decodeIfPresent(Bool.self, forKey: .verseReminderEnabled) ?? defaults.verseReminderEnabled,
            verseReminderTime: try c.decodeIfPresent(TimeOfDay.self, forKey: .verseReminderTime) ?? defaults.verseReminderTime
        )
    }
}
