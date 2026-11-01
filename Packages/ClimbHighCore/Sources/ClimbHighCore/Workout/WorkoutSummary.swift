import Foundation

/// A finished set as stored in history and backups.
public struct LoggedSet: Codable, Hashable, Sendable {
    public var intensity: SetIntensity
    public var completedAt: Date
    public var plannedRestSeconds: Int
    /// Optional details. Empty / nil when you only used the timer.
    public var exercise: String
    public var weight: Double?
    public var reps: Int?

    public init(intensity: SetIntensity, completedAt: Date, plannedRestSeconds: Int, exercise: String = "", weight: Double? = nil, reps: Int? = nil) {
        self.intensity = intensity
        self.completedAt = completedAt
        self.plannedRestSeconds = plannedRestSeconds
        self.exercise = exercise
        self.weight = weight
        self.reps = reps
    }
}

/// Totals for one workout, shown at the end and in history.
public struct WorkoutSummary: Equatable, Sendable {
    public let totalSets: Int
    public let setsByIntensity: [SetIntensity: Int]
    public let duration: TimeInterval
    /// Sum of weight × reps for sets that recorded both.
    public let totalVolume: Double
    public let exercises: [String]

    public init(sets: [LoggedSet], startedAt: Date, endedAt: Date) {
        totalSets = sets.count
        setsByIntensity = Dictionary(grouping: sets, by: \.intensity).mapValues(\.count)
        duration = max(0, endedAt.timeIntervalSince(startedAt))
        totalVolume = sets.reduce(0) { total, set in
            guard let weight = set.weight, let reps = set.reps else { return total }
            return total + weight * Double(reps)
        }
        var seen = Set<String>()
        exercises = sets.compactMap { set in
            let name = set.exercise.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { return nil }
            return name
        }
    }

    public func count(for intensity: SetIntensity) -> Int {
        setsByIntensity[intensity, default: 0]
    }
}
