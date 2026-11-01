import ClimbHighCore
import SwiftUI

// Reusable building blocks. Screens should be assembled from these instead
// of re-styling raw views, so the whole app keeps one look.

/// Full-screen app background.
struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Palette.background.ignoresSafeArea())
            .scrollContentBackground(.hidden)
    }
}

extension View {
    func screenBackground() -> some View { modifier(ScreenBackground()) }

    /// Rounded "card" surface used across the app.
    func card(padding: CGFloat = Metrics.cardPadding, color: Color = Palette.surface) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
    }
}

/// The big, bold headline at the top of each screen ("Current Vacancies" style).
struct BigTitle: View {
    let text: String
    var eyebrow: String?
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(Palette.textSecondary)
            }
            Text(text)
                .font(.system(size: size, weight: .heavy))
                .tracking(-1.2)
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Small section label above a group of cards.
struct SectionLabel: View {
    let text: String
    var trailing: AnyView?

    init(_ text: String, trailing: AnyView? = nil) {
        self.text = text
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(text)
                .font(.title3.weight(.bold))
                .foregroundStyle(Palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            trailing
        }
    }
}

/// Primary pill button (lime with dark text) and a quieter secondary version.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive }
    var kind: Kind = .primary
    var fill: Color?
    var textColor: Color?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 22)
            .frame(minHeight: 52)
            .frame(maxWidth: .infinity)
            .foregroundStyle(foreground)
            .background(background, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }

    private var foreground: Color {
        if let textColor { return textColor }
        switch kind {
        case .primary: Palette.ink
        case .secondary: Palette.textPrimary
        case .destructive: Palette.ink
        }
    }

    private var background: Color {
        if let fill { return fill }
        switch kind {
        case .primary: return Palette.volt
        case .secondary: return Palette.surfaceRaised
        case .destructive: return Palette.coral
        }
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pill: PillButtonStyle { PillButtonStyle() }
    static var pillSecondary: PillButtonStyle { PillButtonStyle(kind: .secondary) }
    static func pillFilled(_ fill: Color) -> PillButtonStyle { PillButtonStyle(kind: .primary, fill: fill) }
}

/// Round icon button with a guaranteed 44×44 tap area and a spoken label.
struct CircleIconButton: View {
    let systemImage: String
    let label: String
    var fill: Color = Palette.surfaceRaised
    var foreground: Color = Palette.textPrimary
    var size: CGFloat = 48
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: max(size, Metrics.minTapTarget), height: max(size, Metrics.minTapTarget))
                .background(fill, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Small rounded tag, e.g. "Alarm" or "3 nudges".
struct Chip: View {
    let text: String
    var systemImage: String?
    var color: Color = Palette.surfaceRaised
    var foreground: Color = Palette.textPrimary

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(foreground)
        .background(color, in: Capsule())
    }
}

/// Large colored tile for picking a rest (Light / Heavy / Failure).
struct IntensityTile: View {
    let intensity: SetIntensity
    let seconds: Int
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: compact ? 6 : 10) {
                HStack {
                    Image(systemName: intensity.symbol)
                        .font(.title3.weight(.bold))
                    Spacer()
                    Text(Clock.format(TimeInterval(seconds)))
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .monospacedDigit()
                }
                Text(intensity.title)
                    .font(compact ? .title3.weight(.heavy) : .title.weight(.heavy))
                if !compact {
                    Text(intensity.guidance)
                        .font(.footnote.weight(.medium))
                        .opacity(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(compact ? 14 : 18)
            .frame(maxWidth: .infinity, minHeight: compact ? 96 : 132, alignment: .topLeading)
            .background(intensity.color, in: RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(intensity.title) set, rest \(Clock.format(TimeInterval(seconds)))")
        .accessibilityHint("Logs the set you just finished and starts the rest timer.")
    }
}

/// Subtle press feedback for custom-drawn buttons.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Friendly empty state used by lists.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Palette.accent)
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Palette.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .card()
    }
}

/// Inline banner for warnings and status messages.
struct NoticeBanner: View {
    let text: String
    var systemImage: String = "info.circle.fill"
    var color: Color = Palette.lilac

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(Palette.ink)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
