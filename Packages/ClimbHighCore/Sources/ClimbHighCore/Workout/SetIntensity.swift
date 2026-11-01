import Foundation

/// The three kinds of set the rest timer knows about.
public enum SetIntensity: String, Codable, CaseIterable, Identifiable, Sendable {
    case light
    case heavy
    case failure

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .light: "Light"
        case .heavy: "Heavy"
        case .failure: "Failure"
        }
    }

    /// One-line description shown under each button.
    public var guidance: String {
        switch self {
        case .light: "Moderate weight · 8–15+ reps"
        case .heavy: "Near your max · 1–6 reps"
        case .failure: "Taken to failure · no reps left"
        }
    }
}

/// Rest length for each intensity, in seconds. Fully editable in Settings.
///
/// Defaults (see docs/REST-TIMES.md for sources):
/// - Light 90 s — a 2024 meta-analysis found a small hypertrophy benefit
///   above 60 s and no detectable extra benefit beyond ~90 s.
/// - Heavy 180 s — trained lifters gained more strength resting 3 min vs 1 min.
/// - Failure 240 s — ESTIMATE. No study isolates rest after failure sets;
///   failure adds short-term fatigue, so one extra minute over heavy.
public struct RestPresets: Codable, Equatable, Sendable {
    public var light: Int
    public var heavy: Int
    public var failure: Int

    public static let evidenceBased = RestPresets(light: 90, heavy: 180, failure: 240)
    /// Allowed range in the editor: 15 s to 15 min.
    public static let allowedSeconds = 15...900

    public init(light: Int, heavy: Int, failure: Int) {
        self.light = Self.clamp(light)
        self.heavy = Self.clamp(heavy)
        self.failure = Self.clamp(failure)
    }

    public func seconds(for intensity: SetIntensity) -> Int {
        switch intensity {
        case .light: light
        case .heavy: heavy
        case .failure: failure
        }
    }

    public mutating func setSeconds(_ seconds: Int, for intensity: SetIntensity) {
        let value = Self.clamp(seconds)
        switch intensity {
        case .light: light = value
        case .heavy: heavy = value
        case .failure: failure = value
        }
    }

    private static func clamp(_ seconds: Int) -> Int {
        min(max(seconds, allowedSeconds.lowerBound), allowedSeconds.upperBound)
    }
}
