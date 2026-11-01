import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

/// Lock Screen + Dynamic Island UI for rest timers and snoozed reminder alarms.
/// AlarmKit fills in `context.state` (countdown / paused / alerting); we only draw it.
struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<ClimbHighAlarmMetadata>.self) { context in
            LockScreenView(metadata: context.attributes.metadata, state: context.state)
                .activityBackgroundTint(SharedPalette.ink)
                .activitySystemActionForegroundColor(SharedPalette.volt)
        } dynamicIsland: { context in
            let metadata = context.attributes.metadata
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    KindIcon(metadata: metadata)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownLabel(state: context.state)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(SharedPalette.volt)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(metadata?.title ?? "Climb High")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                KindIcon(metadata: metadata, size: 22)
            } compactTrailing: {
                CountdownLabel(state: context.state)
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(SharedPalette.volt)
                    .frame(maxWidth: 52)
            } minimal: {
                KindIcon(metadata: metadata, size: 22)
            }
            .keylineTint(SharedPalette.volt)
        }
    }
}

private struct LockScreenView: View {
    let metadata: ClimbHighAlarmMetadata?
    let state: AlarmPresentationState

    var body: some View {
        HStack(spacing: 14) {
            KindIcon(metadata: metadata, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(metadata?.title ?? "Climb High")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(metadata?.subtitle ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            CountdownLabel(state: state)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(SharedPalette.volt)
                .multilineTextAlignment(.trailing)
        }
        .padding(18)
    }
}

/// "1:23" while counting down, "Paused", or "Now" when the alarm is ringing.
private struct CountdownLabel: View {
    let state: AlarmPresentationState

    var body: some View {
        switch state.mode {
        case .countdown(let countdown):
            Text(timerInterval: Date.now...max(Date.now, countdown.fireDate), countsDown: true)
                .monospacedDigit()
        case .paused:
            Text("Paused")
        case .alert:
            Text("Now")
        @unknown default:
            Text("")
        }
    }
}

private struct KindIcon: View {
    let metadata: ClimbHighAlarmMetadata?
    var size: CGFloat = 32

    var body: some View {
        let isRest = metadata?.kind == .rest
        Image(systemName: isRest ? "figure.strengthtraining.traditional" : "bell.fill")
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(SharedPalette.ink)
            .frame(width: size, height: size)
            .background(isRest ? SharedPalette.volt : SharedPalette.sky, in: Circle())
            .accessibilityHidden(true)
    }
}
