import ClimbHighCore
import SwiftData
import SwiftUI

/// Workout mode. Before a workout: a start card. During: the three rest
/// buttons, a live rest timer, and your set count.
struct WorkoutView: View {
    @Environment(WorkoutController.self) private var workout
    @Environment(SettingsStore.self) private var settings
    @State private var showDetails = false
    @State private var details = WorkoutController.SetDetails()
    @State private var editingTimes = false
    @State private var confirmEnd = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BigTitle(text: workout.isActive ? "Lift." : "Workout", eyebrow: header)

                if let notice = workout.notice {
                    NoticeBanner(text: notice, systemImage: "exclamationmark.triangle.fill", color: Palette.coral)
                        .onTapGesture { workout.notice = nil }
                }

                if let rest = workout.rest {
                    RestTimerPanel(rest: rest)
                } else if workout.isActive {
                    pickRest
                } else {
                    startCard
                }

                if workout.isActive {
                    sessionStats
                }

                NavigationLink {
                    WorkoutHistoryView()
                } label: {
                    HStack {
                        Label("History", systemImage: "clock.arrow.circlepath")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote.weight(.bold))
                    }
                    .foregroundStyle(Palette.textPrimary)
                    .card(padding: 18)
                }
                .buttonStyle(PressableStyle())
            }
            .padding(Metrics.screenPadding)
        }
        .screenBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Rest times") { editingTimes = true }
            }
        }
        .sheet(isPresented: $editingTimes) {
            NavigationStack { RestTimesEditor() }
                .presentationDetents([.medium, .large])
        }
        .sheet(item: Binding(get: { workout.finishedSession }, set: { if $0 == nil { workout.dismissSummary() } })) { session in
            WorkoutSummaryView(session: session)
                .presentationDetents([.medium])
        }
        .confirmationDialog("End this workout?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End workout", role: .destructive) { workout.endSession() }
        }
    }

    private var header: String {
        guard let session = workout.session else { return "Rest timer" }
        return "Started \(session.startedAt.formatted(date: .omitted, time: .shortened))"
    }

    // MARK: Before the workout

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pick a rest after every set. Use your phone while you wait — it'll ring and keep vibrating until you start the next one.")
                .font(.body)
                .foregroundStyle(Palette.textSecondary)
            if settings.settings.focusAutomationEnabled {
                Label("Focus turns on automatically", systemImage: "moon.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.accent)
            }
            Button("Start workout") { workout.startSession() }
                .buttonStyle(.pill)
        }
        .card()
    }

    // MARK: Between sets

    private var pickRest: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel("Set done? Pick your rest")
            ForEach(SetIntensity.allCases) { intensity in
                IntensityTile(intensity: intensity, seconds: settings.settings.restPresets.seconds(for: intensity)) {
                    workout.finishSet(intensity, details: showDetails ? details : .init())
                    details.repsText = ""

                }
            }
            DisclosureGroup(isExpanded: $showDetails) {
                SetDetailsFields(details: $details)
                    .padding(.top, 8)
            } label: {
                Label("Log exercise, weight & reps", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.textPrimary)
            }
            .tint(Palette.accent)
            .card(padding: 16)
        }
    }

    private var sessionStats: some View {
        let summary = workout.session?.summary
        return VStack(spacing: 12) {
            HStack(spacing: 10) {
                StatTile(value: "\(summary?.totalSets ?? 0)", label: "Sets", color: Palette.surface)
                ForEach(SetIntensity.allCases) { intensity in
                    StatTile(value: "\(summary?.count(for: intensity) ?? 0)", label: intensity.title, color: intensity.color.opacity(0.25))
                }
            }
            Button("End workout") { confirmEnd = true }
                .buttonStyle(.pillSecondary)
        }
    }
}

/// The big countdown shown during a rest.
private struct RestTimerPanel: View {
    let rest: RestPeriod
    @Environment(WorkoutController.self) private var workout
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let isOver = workout.isRestOver || rest.isFinished(at: context.date)
            VStack(spacing: 20) {
                Text(isOver ? "REST'S UP" : "\(rest.intensity.title.uppercased()) REST")
                    .font(.caption.weight(.heavy))
                    .tracking(1.5)

                ZStack {
                    Circle()
                        .stroke(Palette.ink.opacity(0.15), lineWidth: 16)
                    Circle()
                        .trim(from: 0, to: 1 - rest.progress(at: context.date))
                        .stroke(Palette.ink, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(reduceMotion ? nil : .linear(duration: 0.25), value: context.date)
                    VStack(spacing: 4) {
                        Text(isOver ? "GO" : Clock.format(rest.remaining(at: context.date)))
                            .font(.system(size: 64, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                        Text(isOver ? "Next set" : "Set \(workout.setCount + 1) next")
                            .font(.subheadline.weight(.semibold))
                            .opacity(0.7)
                    }
                }
                .frame(width: 230, height: 230)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(isOver ? "Rest is over" : "\(Clock.format(rest.remaining(at: context.date))) of rest left")

                if isOver {
                    Button("Start set") { workout.startNextSet() }
                        .buttonStyle(PillButtonStyle(kind: .primary, fill: Palette.ink, textColor: rest.intensity.color))
                } else {
                    HStack(spacing: 12) {
                        Button("−15s") { workout.adjustRest(by: -15) }
                            .accessibilityLabel("Remove 15 seconds")
                        Button("+15s") { workout.adjustRest(by: 15) }
                            .accessibilityLabel("Add 15 seconds")
                        Button("Skip") { workout.startNextSet() }
                            .accessibilityLabel("Skip rest and start set")
                    }
                    .buttonStyle(PillButtonStyle(kind: .secondary, fill: Palette.ink.opacity(0.12), textColor: Palette.ink))
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(rest.intensity.color, in: RoundedRectangle(cornerRadius: 36, style: .continuous))
            .sensoryFeedback(.warning, trigger: isOver)
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .monospacedDigit()
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.textSecondary)
        }
        .foregroundStyle(Palette.textPrimary)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Optional exercise / weight / reps fields for the next logged set.
private struct SetDetailsFields: View {
    @Binding var details: WorkoutController.SetDetails

    var body: some View {
        VStack(spacing: 10) {
            TextField("Exercise (e.g. Bench press)", text: $details.exercise)
                .textInputAutocapitalization(.words)
                .padding(12)
                .background(Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
            HStack(spacing: 10) {
                TextField("Weight", text: $details.weightText)
                    .keyboardType(.decimalPad)
                    .padding(12)
                    .background(Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
                TextField("Reps", text: $details.repsText)
                    .keyboardType(.numberPad)
                    .padding(12)
                    .background(Palette.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
            }
            Text("Saved with the next set you log. Exercise and weight stay filled in for the next set.")
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.body)
    }
}

/// Edit the three rest lengths (also in Settings).
struct RestTimesEditor: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                ForEach(SetIntensity.allCases) { intensity in
                    Stepper(
                        value: Binding(
                            get: { settings.settings.restPresets.seconds(for: intensity) },
                            set: { newValue in settings.update { $0.restPresets.setSeconds(newValue, for: intensity) } }
                        ),
                        in: RestPresets.allowedSeconds,
                        step: 15
                    ) {
                        HStack {
                            Circle().fill(intensity.color).frame(width: 12, height: 12)
                            Text(intensity.title).font(.headline)
                            Spacer()
                            Text(Clock.format(TimeInterval(settings.settings.restPresets.seconds(for: intensity))))
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                }
            } footer: {
                Text("Defaults: Light 1:30, Heavy 3:00, Failure 4:00. Research: rest over 60–90 s helps muscle growth; about 3 min+ helps strength. The failure time is an estimate — adjust to how you feel.")
            }

            Section {
                Button("Reset to research-based defaults") {
                    settings.update { $0.restPresets = .evidenceBased }
                }
            }
        }
        .navigationTitle("Rest times")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}
