import AlarmKit
import SwiftUI

/// Data attached to every AlarmKit alarm the app schedules. The widget
/// extension reads it to draw the Lock Screen / Dynamic Island countdown.
///
/// This file is compiled into BOTH the app and the widget extension.
struct ClimbHighAlarmMetadata: AlarmMetadata {
    enum Kind: String, Codable, Hashable, Sendable {
        case rest
        case reminder
    }

    var kind: Kind
    var title: String
    var subtitle: String
}

/// The brand colors the widget needs (the app has the full design system).
enum SharedPalette {
    static let volt = Color(red: 0.831, green: 1.0, blue: 0.231)   // #D4FF3B
    static let coral = Color(red: 1.0, green: 0.541, blue: 0.478)  // #FF8A7A
    static let sky = Color(red: 0.361, green: 0.839, blue: 0.961)  // #5CD6F5
    static let ink = Color(red: 0.043, green: 0.043, blue: 0.051)  // #0B0B0D
}
