import ClimbHighCore
import SwiftData
import SwiftUI

/// Home screen: what's next, quick rest buttons, latest note, and the assistant.
struct TodayView: View {
    @Binding var selection: AppTab

    @Environment(ReminderStore.self) private var reminders
    @Environment(WorkoutController.self) private var workout
    @Environment(SettingsStore.self) private var settings
    @Query(sort: \Reminder.createdAt) private var allReminders: [Reminder]
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BigTitle(text: "Climb\nhigh.", eyebrow: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                VerseCard()
                nextUp
                workoutCard
                latestNote
                assistantPrompt
            }
            .padding(Metrics.screenPadding)
        }
        .screenBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .accessibilityLabel("Settings")
                }
            }
        }
    }

    // MARK: Sections

    private var upcoming: [ReminderStore.AgendaItem] {
        // `allReminders` is read so this view refreshes when reminders change.
        _ = allReminders.count
        return reminders.agenda().filter { $0.entry.section != .done }
    }

    private var nextUp: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Next up", trailing: AnyView(
                Button("See all") { selection = .reminders }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.accent)
            ))
            if upcoming.isEmpty {
                Button {
                    selection = .reminders
                } label: {
                    HStack {
                        Text("Nothing on deck. Add a reminder")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                    .foregroundStyle(Palette.textPrimary)
                    .card()
                }
                .buttonStyle(PressableStyle())
            } else {
                VStack(spacing: 10) {
                    let accents = [Palette.volt, Palette.coral, Palette.sky]
                    ForEach(Array(upcoming.prefix(3).enumerated()), id: \.offset) { index, item in
                        UpcomingRow(reminder: item.reminder, entry: item.entry, accent: accents[index % accents.count])
                    }
                }
            }
        }
    }

    private var workoutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Workout", trailing: AnyView(
                Button(workout.isActive ? "Open" : "Start") { selection = .workout }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.accent)
            ))
            if let rest = workout.rest {
                Button { selection = .workout } label: {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.isRestOver ? "Rest's up" : "\(rest.intensity.title) rest")
                                    .font(.headline)
                                Text(workout.isRestOver ? "Tap to start your set" : "Set \(workout.setCount + 1) is next")
                                    .font(.subheadline).opacity(0.75)
                            }
                            Spacer()
                            Text(Clock.format(rest.remaining(at: context.date)))
                                .font(.system(size: 40, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                        }
                        .foregroundStyle(Palette.ink)
                        .card(color: rest.intensity.color)
                    }
                }
                .buttonStyle(PressableStyle())
            } else {
                HStack(spacing: 10) {
                    ForEach(SetIntensity.allCases) { intensity in
                        IntensityTile(intensity: intensity, seconds: settings.settings.restPresets.seconds(for: intensity), compact: true) {
                            workout.finishSet(intensity)
                            selection = .workout
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var latestNote: some View {
        if let note = notes.first {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel("Latest note", trailing: AnyView(
                    Button("All notes") { selection = .notes }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                ))
                NavigationLink {
                    NoteEditorView(note: note)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(note.displayTitle)
                            .font(.headline)
                            .foregroundStyle(Palette.textPrimary)
                        Text(note.content)
                            .font(.subheadline)
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    .card()
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private var assistantPrompt: some View {
        Button { selection = .assistant } label: {
            HStack(spacing: 14) {
                PipView(mood: .idle, size: 36)
                    .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask Pip anything")
                        .font(.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text("“Remind me to call Mom tomorrow at 5”")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
            }
            .card()
        }
        .buttonStyle(PressableStyle())
    }
}

private struct UpcomingRow: View {
    let reminder: Reminder
    let entry: AgendaEntry
    let accent: Color

    var body: some View {
        NavigationLink {
            ReminderEditorView(reminder: reminder)
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 4).fill(accent).frame(width: 6, height: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text(reminder.title)
                        .font(.headline)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                    Text(ReminderFormatting.when(entry.occurrence, section: entry.section))
                        .font(.subheadline)
                        .foregroundStyle(entry.section == .overdue ? Palette.coral : Palette.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.textSecondary)
            }
            .card(padding: 16)
        }
        .buttonStyle(PressableStyle())
    }
}
