import SwiftUI
import WidgetKit

/// Entry point of the widget extension. Its only job is drawing the
/// countdown that AlarmKit shows on the Lock Screen and in the Dynamic Island.
/// (AlarmKit requires this extension for countdown alarms.)
@main
struct ClimbHighWidgetsBundle: WidgetBundle {
    var body: some Widget {
        AlarmLiveActivity()
    }
}
