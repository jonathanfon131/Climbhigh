import Foundation

public enum LeadTimeUnit: String, Codable, CaseIterable, Sendable {
    case minutes, hours, days, weeks

    var calendarComponent: Calendar.Component {
        switch self {
        case .minutes: .minute
        case .hours: .hour
        case .days: .day
        case .weeks: .weekOfYear
        }
    }

    func label(for amount: Int) -> String {
        let singular: String
        switch self {
        case .minutes: singular = "minute"
        case .hours: singular = "hour"
        case .days: singular = "day"
        case .weeks: singular = "week"
        }
        return amount == 1 ? singular : singular + "s"
    }
}

/// How long before something is due an early "heads-up" warning fires,
/// for example "3 days" or "2 hours".
public struct LeadTime: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var amount: Int
    public var unit: LeadTimeUnit

    public init(id: UUID = UUID(), amount: Int, unit: LeadTimeUnit) {
        self.id = id
        self.amount = max(1, amount)
        self.unit = unit
    }

    /// When this warning fires for something due at `due`.
    ///
    /// Days and weeks use calendar math, so "1 day before 9:00 AM" stays at
    /// 9:00 AM even across a daylight-saving change.
    public func fireDate(before due: Date, calendar: Calendar) -> Date? {
        calendar.date(byAdding: unit.calendarComponent, value: -amount, to: due)
    }

    /// "3 days" — the length on its own.
    public var lengthLabel: String { "\(amount) \(unit.label(for: amount))" }

    /// "3 days before" — used in the editor.
    public var label: String { "\(lengthLabel) before" }
}
