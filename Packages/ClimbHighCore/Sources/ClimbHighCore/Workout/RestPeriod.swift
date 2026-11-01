import Foundation

/// One running rest between sets. All timing is derived from dates, so it
/// stays correct if the app is closed, suspended, or relaunched mid-rest.
public struct RestPeriod: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let intensity: SetIntensity
    public let startedAt: Date
    public private(set) var duration: TimeInterval

    public init(id: UUID = UUID(), intensity: SetIntensity, startedAt: Date, duration: TimeInterval) {
        self.id = id
        self.intensity = intensity
        self.startedAt = startedAt
        self.duration = max(0, duration)
    }

    public var endsAt: Date { startedAt.addingTimeInterval(duration) }

    public func remaining(at now: Date) -> TimeInterval {
        max(0, endsAt.timeIntervalSince(now))
    }

    public func isFinished(at now: Date) -> Bool {
        now >= endsAt
    }

    /// 0 at the start, 1 when the rest is over.
    public func progress(at now: Date) -> Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(startedAt) / duration))
    }

    /// Adds (or with a negative value, removes) rest time.
    /// Removing time never ends the rest in the past — at most it ends now.
    public mutating func adjust(by seconds: TimeInterval, now: Date) {
        let elapsed = max(0, now.timeIntervalSince(startedAt))
        duration = max(elapsed, duration + seconds)
    }
}
