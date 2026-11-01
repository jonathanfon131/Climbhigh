import SwiftUI

/// What Pip is doing right now. Each mood has its own little animation.
enum PipMood: Equatable {
    /// Gentle float and blinks.
    case idle
    /// Eyes glance up, a thought bubble of dots bobs above.
    case thinking
    /// Sound rings pulse out while you talk.
    case listening
    /// Happy ^ ^ eyes and a bounce — after it does something for you.
    case happy
    /// Eyes closed, floating "z" — the on-device AI is off.
    case sleepy
}

/// Pip — Climb High's little assistant: a round sprout-topped buddy.
///
/// Drawn entirely with SwiftUI shapes (no image assets), animated from the
/// clock with `TimelineView`, and frozen in a calm pose when Reduce Motion is on.
struct PipView: View {
    var mood: PipMood = .idle
    var size: CGFloat = 64
    /// Small avatars in long chats can be still to save battery.
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || !animated)) { context in
            let t = (reduceMotion || !animated) ? 0 : context.date.timeIntervalSinceReferenceDate
            ZStack {
                if mood == .listening { listeningRings(t) }
                character(t)
                    .offset(y: bob(t))
                    .scaleEffect(x: squish(t).x, y: squish(t).y, anchor: .bottom)
                if mood == .thinking { thoughtDots(t) }
                if mood == .sleepy { sleepyZ(t) }
            }
            .frame(width: size * 1.5, height: size * 1.5)
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    // MARK: Pieces

    private func character(_ t: TimeInterval) -> some View {
        ZStack {
            // Sprout on top
            HStack(spacing: -size * 0.04) {
                Ellipse().fill(Palette.volt)
                    .frame(width: size * 0.26, height: size * 0.14)
                    .rotationEffect(.degrees(-30 + sway(t)))
                Ellipse().fill(Palette.volt)
                    .frame(width: size * 0.26, height: size * 0.14)
                    .rotationEffect(.degrees(30 + sway(t)))
            }
            .offset(y: -size * 0.52)

            // Body
            RoundedRectangle(cornerRadius: size * 0.42, style: .continuous)
                .fill(LinearGradient(colors: [Palette.lilac, Palette.sky], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size, height: size * 0.92)
                .overlay(alignment: .topLeading) {
                    // Shine
                    Ellipse().fill(.white.opacity(0.45))
                        .frame(width: size * 0.22, height: size * 0.12)
                        .rotationEffect(.degrees(-25))
                        .offset(x: size * 0.14, y: size * 0.12)
                }

            // Face
            VStack(spacing: size * 0.06) {
                HStack(spacing: size * 0.24) {
                    eye(t)
                    eye(t)
                }
                .offset(x: eyeLook.x * size, y: eyeLook.y * size)
                HStack(spacing: size * 0.42) {
                    Circle().fill(Palette.coral.opacity(0.7)).frame(width: size * 0.12)
                    Circle().fill(Palette.coral.opacity(0.7)).frame(width: size * 0.12)
                }
                .frame(height: size * 0.06)
                mouth
            }
            .offset(y: size * 0.04)
        }
    }

    @ViewBuilder
    private func eye(_ t: TimeInterval) -> some View {
        switch mood {
        case .happy:
            HappyEye()
                .stroke(Palette.ink, style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round))
                .frame(width: size * 0.13, height: size * 0.08)
        case .sleepy:
            Capsule().fill(Palette.ink)
                .frame(width: size * 0.13, height: size * 0.035)
        default:
            Capsule().fill(Palette.ink)
                .frame(width: size * 0.1, height: size * 0.15)
                .scaleEffect(y: isBlinking(t) ? 0.12 : 1)
        }
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .thinking:
            Circle().stroke(Palette.ink, lineWidth: size * 0.035)
                .frame(width: size * 0.07)
        case .listening:
            Capsule().fill(Palette.ink)
                .frame(width: size * 0.12, height: size * 0.08)
        default:
            Smile()
                .stroke(Palette.ink, style: StrokeStyle(lineWidth: size * 0.04, lineCap: .round))
                .frame(width: mood == .happy ? size * 0.2 : size * 0.14, height: size * 0.06)
        }
    }

    private func thoughtDots(_ t: TimeInterval) -> some View {
        HStack(spacing: size * 0.06) {
            ForEach(0..<3, id: \.self) { index in
                Circle().fill(Palette.textSecondary)
                    .frame(width: size * 0.09)
                    .offset(y: -CGFloat(abs(sin(t * 4 + Double(index) * 0.7))) * size * 0.08)
            }
        }
        .offset(x: size * 0.48, y: -size * 0.62)
    }

    private func listeningRings(_ t: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                let phase = CGFloat((t * 0.9 + Double(index) * 0.5).truncatingRemainder(dividingBy: 1))
                Circle()
                    .stroke(Palette.coral.opacity(Double(1 - phase)), lineWidth: 3)
                    .frame(width: size * (1 + phase * 0.5), height: size * (1 + phase * 0.5))
            }
        }
    }

    private func sleepyZ(_ t: TimeInterval) -> some View {
        let phase = CGFloat((t * 0.4).truncatingRemainder(dividingBy: 1))
        return Text("z")
            .font(.system(size: size * 0.24, weight: .heavy, design: .rounded))
            .foregroundStyle(Palette.textSecondary)
            .opacity(Double(1 - phase))
            .offset(x: size * 0.45 + phase * size * 0.15, y: -size * 0.5 - phase * size * 0.3)
    }

    // MARK: Motion (all derived from time `t`)

    private func bob(_ t: TimeInterval) -> CGFloat {
        let wave: Double
        switch mood {
        case .happy: wave = -abs(sin(t * 6)) * 0.1
        case .thinking: wave = sin(t * 3) * 0.03
        case .sleepy: wave = sin(t * 1) * 0.02
        default: wave = sin(t * 2) * 0.035
        }
        return CGFloat(wave) * size
    }

    private func squish(_ t: TimeInterval) -> (x: CGFloat, y: CGFloat) {
        guard mood == .happy else { return (1, 1) }
        let s = CGFloat(abs(sin(t * 6)))
        return (1 + (1 - s) * 0.06, 1 - (1 - s) * 0.06)
    }

    private func sway(_ t: TimeInterval) -> Double {
        sin(t * 2.2) * 8
    }

    private func isBlinking(_ t: TimeInterval) -> Bool {
        t.truncatingRemainder(dividingBy: 3.6) < 0.12
    }

    private var eyeLook: CGPoint {
        mood == .thinking ? CGPoint(x: 0.05, y: -0.05) : .zero
    }

    private var accessibilityText: String {
        switch mood {
        case .idle: "Pip"
        case .thinking: "Pip is thinking"
        case .listening: "Pip is listening"
        case .happy: "Pip is happy"
        case .sleepy: "Pip is asleep"
        }
    }
}

/// ‿ shaped smile.
private struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.midX, y: rect.maxY * 1.6))
        return path
    }
}

/// ^ shaped closed happy eye.
private struct HappyEye: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.6))
        return path
    }
}
