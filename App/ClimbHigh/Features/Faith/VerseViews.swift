import ClimbHighCore
import SwiftUI

/// "Verse of the day" card on the Today screen.
struct VerseCard: View {
    @Environment(FaithStore.self) private var faith

    var body: some View {
        if let verse = faith.todayVerse {
            let streak = faith.streak
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("VERSE OF THE DAY")
                        .font(.caption.weight(.heavy))
                        .tracking(1.2)
                    Spacer()
                    StreakBadge(streak: streak)
                }
                NavigationLink {
                    VerseDetailView()
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(verse.text)
                            .font(.system(.title3, design: .serif))
                            .multilineTextAlignment(.leading)
                            .lineLimit(7)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Text(verse.reference)
                                .font(.subheadline.weight(.bold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.bold))
                        }
                    }
                }
                .buttonStyle(.plain)
                ReadTodayButton()
            }
            .foregroundStyle(Palette.ink)
            .card(color: Palette.lilac)
        }
    }
}

/// "I read it" → marks today and grows the streak (with a little celebration).
struct ReadTodayButton: View {
    @Environment(FaithStore.self) private var faith

    var body: some View {
        let isRead = faith.streak.readToday
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                faith.markTodayRead()
            }
        } label: {
            Label(isRead ? "Read today" : "I read it", systemImage: isRead ? "checkmark.circle.fill" : "book.fill")
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PillButtonStyle(kind: .primary, fill: isRead ? Palette.ink.opacity(0.12) : Palette.ink, textColor: isRead ? Palette.ink : Palette.volt))
        .disabled(isRead)
        .sensoryFeedback(.success, trigger: isRead)
        .accessibilityHint(isRead ? "Already counted for today" : "Counts today toward your streak")
    }
}

/// Flame + day count. Lit once today's verse is read; bounces when it grows.
struct StreakBadge: View {
    let streak: ReadingStreak

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(streak.readToday ? Palette.coral : Palette.ink.opacity(0.35))
                .symbolEffect(.bounce, value: streak.current)
            Text("\(streak.current)")
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(streak.current)))
        }
        .font(.headline.weight(.heavy))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.white.opacity(0.45), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(streak.current)-day streak\(streak.readToday ? "" : ", read today to keep it")")
    }
}

/// Full verse, streak stats, the last two weeks, and share.
struct VerseDetailView: View {
    @Environment(FaithStore.self) private var faith

    var body: some View {
        let streak = faith.streak
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BigTitle(text: "Daily verse", eyebrow: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))

                if let verse = faith.todayVerse {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(verse.text)
                            .font(.system(.title2, design: .serif))
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                        Text(verse.reference)
                            .font(.headline)
                        ReadTodayButton()
                    }
                    .foregroundStyle(Palette.ink)
                    .card(color: Palette.lilac)

                    ShareLink(item: verse.shareText) {
                        Label("Share this verse", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.pillSecondary)
                } else {
                    NoticeBanner(text: "The verse list couldn't be loaded. Reinstalling the app fixes this.", color: Palette.coral)
                }

                HStack(spacing: 10) {
                    StreakStat(value: streak.current, label: "Day streak", systemImage: "flame.fill", color: Palette.coral)
                    StreakStat(value: streak.best, label: "Best", systemImage: "trophy.fill", color: Palette.volt)
                    StreakStat(value: streak.total, label: "Days read", systemImage: "book.fill", color: Palette.sky)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Last 2 weeks")
                        .font(.headline)
                        .foregroundStyle(Palette.textPrimary)
                    HStack(spacing: 6) {
                        ForEach(Array(faith.recentDays(14).enumerated()), id: \.offset) { _, item in
                            Circle()
                                .fill(item.read ? Palette.volt : Palette.surfaceRaised)
                                .overlay(Circle().stroke(item.day == faith.currentDay ? Palette.accent : .clear, lineWidth: 2))
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .accessibilityLabel("\(item.day.description): \(item.read ? "read" : "not read")")
                        }
                    }
                    if let next = streak.nextMilestone {
                        Text("\(next - streak.current) more day\(next - streak.current == 1 ? "" : "s") to a \(next)-day streak.")
                            .font(.subheadline)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .card()

                Text("Scripture quotations are from the Berean Standard Bible (BSB), which is in the public domain.")
                    .font(.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(Metrics.screenPadding)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StreakStat: View {
    let value: Int
    let label: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.headline)
            Text("\(value)")
                .font(.system(.title, design: .rounded).weight(.heavy))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
            Text(label)
                .font(.caption.weight(.semibold))
                .opacity(0.75)
        }
        .foregroundStyle(Palette.ink)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Shown when a streak hits 3, 7, 14, 30… days. Pip celebrates with confetti.
struct MilestoneCelebration: View {
    let days: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if !reduceMotion { ConfettiView() }
            VStack(spacing: 14) {
                PipView(mood: .happy, size: 90)
                    .frame(width: 135, height: 135)
                Text("\(days)-day streak!")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundStyle(Palette.textPrimary)
                Text(message)
                    .font(.body)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Keep climbing") { dismiss() }
                    .buttonStyle(.pill)
                    .padding(.top, 8)
            }
            .padding(Metrics.screenPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
        .sensoryFeedback(.success, trigger: days)
    }

    private var message: String {
        switch days {
        case ..<7: "A habit is forming. Pip is proud of you."
        case ..<30: "That's real consistency. Keep showing up."
        case ..<100: "A month and more in the Word. That's a foundation."
        default: "Incredible faithfulness. Keep climbing higher."
        }
    }
}

/// Simple falling confetti, ~2.5 seconds.
struct ConfettiView: View {
    private struct Piece: Identifiable {
        let id = UUID()
        let x: CGFloat
        let color: Color
        let size: CGFloat
        let spin: Double
        let duration: Double
        let delay: Double
    }

    @State private var falling = false
    @State private var pieces: [Piece] = (0..<36).map { _ in
        Piece(
            x: .random(in: 0...1),
            color: [Palette.volt, Palette.coral, Palette.sky, Palette.lilac].randomElement() ?? Palette.volt,
            size: .random(in: 7...13),
            spin: .random(in: 180...720),
            duration: .random(in: 1.8...2.8),
            delay: .random(in: 0...0.5)
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ForEach(pieces) { piece in
                RoundedRectangle(cornerRadius: 2)
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size * 0.6)
                    .rotationEffect(.degrees(falling ? piece.spin : 0))
                    .position(x: piece.x * proxy.size.width, y: falling ? proxy.size.height + 40 : -40)
                    .animation(.easeIn(duration: piece.duration).delay(piece.delay), value: falling)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { falling = true }
    }
}
