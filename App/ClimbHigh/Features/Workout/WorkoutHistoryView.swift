import ClimbHighCore
import SwiftData
import SwiftUI

/// Past workouts, newest first.
struct WorkoutHistoryView: View {
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt != nil }, sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            if sessions.isEmpty {
                EmptyStateView(systemImage: "dumbbell", title: "No workouts yet", message: "Finished workouts show up here with your sets and rest.")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            ForEach(sessions) { session in
                NavigationLink {
                    WorkoutSummaryView(session: session)
                } label: {
                    SessionRow(session: session)
                }
                .listRowBackground(Palette.surface)
            }
            .onDelete { offsets in
                for index in offsets { context.delete(sessions[index]) }
                try? context.save()
            }
        }
        .navigationTitle("History")
        .screenBackground()
    }
}

private struct SessionRow: View {
    let session: WorkoutSession

    var body: some View {
        let summary = session.summary
        VStack(alignment: .leading, spacing: 6) {
            Text(session.startedAt.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.headline)
            HStack(spacing: 6) {
                Chip(text: "\(summary.totalSets) sets")
                Chip(text: Duration.seconds(summary.duration).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                ForEach(SetIntensity.allCases) { intensity in
                    if summary.count(for: intensity) > 0 {
                        Chip(text: "\(summary.count(for: intensity)) \(intensity.title.lowercased())", color: intensity.color, foreground: Palette.ink)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Totals for one workout (shown when you end a workout and from History).
struct WorkoutSummaryView: View {
    let session: WorkoutSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let summary = session.summary
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BigTitle(text: "Nice work.", eyebrow: session.startedAt.formatted(date: .abbreviated, time: .shortened))
                HStack(spacing: 10) {
                    SummaryStat(value: "\(summary.totalSets)", label: "Sets")
                    SummaryStat(value: Duration.seconds(summary.duration).formatted(.units(allowed: [.hours, .minutes], width: .narrow)), label: "Time")
                    if summary.totalVolume > 0 {
                        SummaryStat(value: summary.totalVolume.formatted(.number.precision(.fractionLength(0))), label: "Volume")
                    }
                }
                if !summary.exercises.isEmpty {
                    Text(summary.exercises.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
                VStack(spacing: 8) {
                    ForEach(Array(session.orderedSets.enumerated()), id: \.offset) { index, set in
                        HStack {
                            Text("\(index + 1)")
                                .font(.headline.monospacedDigit())
                                .frame(width: 28)
                            Circle().fill(set.intensity.color).frame(width: 10, height: 10)
                            Text(set.exercise.isEmpty ? set.intensity.title : "\(set.exercise) · \(set.intensity.title)")
                            Spacer()
                            if let weight = set.weight, let reps = set.reps {
                                Text("\(weight.formatted()) × \(reps)")
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.textSecondary)
                            }
                        }
                        .font(.subheadline)
                        .padding(12)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .padding(Metrics.screenPadding)
        }
        .screenBackground()
    }
}

private struct SummaryStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title, design: .rounded).weight(.heavy))
                .foregroundStyle(Palette.ink)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.ink.opacity(0.7))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.volt, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
