import ClimbHighCore
import SwiftUI

/// Create or edit a reminder. Everything about how it alerts is editable:
/// when it's due, how it repeats, heads-up warnings, alarm on/off, and the
/// extra reminder times on the day.
struct ReminderEditorView: View {
    let reminder: Reminder?

    @Environment(ReminderStore.self) private var store
    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ReminderDraft?
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let binding = Binding($draft) {
                ReminderForm(draft: binding)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(reminder == nil ? "New reminder" : "Edit reminder")
        .navigationBarTitleDisplayMode(.inline)
        .screenBackground()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.bold)
                    .disabled(draft?.title.trimmingCharacters(in: .whitespaces).isEmpty ?? true)
            }
            if reminder != nil {
                ToolbarItem(placement: .bottomBar) {
                    Button("Delete reminder", role: .destructive) { confirmDelete = true }
                        .foregroundStyle(Palette.coral)
                }
            }
        }
        .confirmationDialog("Delete this reminder?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let reminder { store.delete(reminder) }
                dismiss()
            }
        }
        .onAppear {
            if draft == nil {
                draft = reminder.map(ReminderDraft.init(reminder:)) ?? ReminderDraft(defaults: settings.settings)
            }
        }
    }

    private func save() {
        guard let draft else { return }
        if let reminder {
            store.update(reminder, title: draft.title, details: draft.details, schedule: draft.schedule)
        } else {
            store.create(title: draft.title, details: draft.details, schedule: draft.schedule)
        }
        dismiss()
    }
}

/// Editable copy of a reminder. Nothing is saved until you tap Save.
struct ReminderDraft {
    /// A row in an editable list needs a stable identity.
    struct EditableTime: Identifiable {
        let id = UUID()
        var time: TimeOfDay
    }

    var title = ""
    var details = ""
    var due: Date
    var repeatRule = RepeatRule.never
    var leadTimes: [LeadTime]
    var ringsAlarm: Bool
    var nudges: [EditableTime]

    init(defaults: AppSettings) {
        // Default: one hour from now, on the hour.
        let inAnHour = Date.now.addingTimeInterval(3_600)
        due = Calendar.current.dateInterval(of: .hour, for: inAnHour)?.start ?? inAnHour
        leadTimes = defaults.defaultLeadTimes.map { LeadTime(amount: $0.amount, unit: $0.unit) }
        ringsAlarm = defaults.defaultRingsAlarm
        nudges = defaults.defaultNudgeTimes.map { EditableTime(time: $0) }
    }

    init(reminder: Reminder) {
        let schedule = reminder.schedule
        title = reminder.title
        details = reminder.details
        due = schedule.firstDue
        repeatRule = schedule.repeatRule
        leadTimes = schedule.leadTimes
        ringsAlarm = schedule.ringsAlarm
        nudges = schedule.dayOfNudges.map { EditableTime(time: $0) }
    }

    var schedule: ReminderSchedule {
        ReminderSchedule(
            firstDue: due,
            repeatRule: repeatRule,
            leadTimes: leadTimes,
            ringsAlarm: ringsAlarm,
            dayOfNudges: Array(Set(nudges.map(\.time)))
        )
    }
}

private struct ReminderForm: View {
    @Binding var draft: ReminderDraft

    var body: some View {
        Form {
            Section {
                TextField("What do you need to remember?", text: $draft.title, axis: .vertical)
                    .font(.title3.weight(.semibold))
                TextField("Details (optional)", text: $draft.details, axis: .vertical)
                    .lineLimit(1...4)
            }

            Section("When") {
                DatePicker("Due", selection: $draft.due)
                Picker("Repeat", selection: $draft.repeatRule.frequency) {
                    Text("Never").tag(RepeatFrequency.never)
                    Text("Daily").tag(RepeatFrequency.daily)
                    Text("Weekly").tag(RepeatFrequency.weekly)
                    Text("Monthly").tag(RepeatFrequency.monthly)
                    Text("Yearly").tag(RepeatFrequency.yearly)
                }
                if draft.repeatRule.isRepeating {
                    Stepper(value: $draft.repeatRule.interval, in: 1...30) {
                        Text(draft.repeatRule.summary)
                    }
                }
                if draft.repeatRule.frequency == .weekly {
                    WeekdayPicker(selection: $draft.repeatRule.weekdays)
                }
            }

            Section {
                ForEach($draft.leadTimes) { $lead in
                    HStack {
                        Stepper(value: $lead.amount, in: 1...365) {
                            Text("\(lead.amount)")
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                        }
                        .fixedSize()
                        Picker("Unit", selection: $lead.unit) {
                            ForEach(LeadTimeUnit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .labelsHidden()
                        Text("before")
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .onDelete { draft.leadTimes.remove(atOffsets: $0) }

                if draft.leadTimes.count < 5 {
                    Button {
                        draft.leadTimes.append(LeadTime(amount: 1, unit: .hours))
                    } label: {
                        Label("Add a heads-up", systemImage: "plus.circle.fill")
                    }
                }
            } header: {
                Text("Heads-up")
            } footer: {
                Text("Notifications before it's due so you see it coming. Swipe left to remove one.")
            }

            Section {
                Toggle(isOn: $draft.ringsAlarm) {
                    Label("Ring as an alarm", systemImage: "alarm.fill")
                }
                ForEach($draft.nudges) { $nudge in
                    DatePicker(
                        "Reminder at",
                        selection: Binding(
                            get: { nudge.time.on(.now, calendar: .current) ?? .now },
                            set: { nudge.time = TimeOfDay(of: $0, calendar: .current) }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
                .onDelete { draft.nudges.remove(atOffsets: $0) }

                if draft.nudges.count < 6 {
                    Button {
                        draft.nudges.append(.init(time: TimeOfDay(hour: 12)))
                    } label: {
                        Label("Add a reminder time", systemImage: "plus.circle.fill")
                    }
                }
            } header: {
                Text("On the day")
            } footer: {
                Text("The alarm rings at the due time — even on Silent or in Focus. The extra times remind you through the day until you tap Done.")
            }
        }
        .scrollContentBackground(.hidden)
    }
}

/// Seven round day buttons (S M T W T F S) for weekly repeats.
private struct WeekdayPicker: View {
    @Binding var selection: Set<Int>
    private let letters = ["S", "M", "T", "W", "T", "F", "S"]
    private let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(letters[day - 1])
                        .font(.subheadline.weight(.bold))
                        .frame(width: 40, height: 44)
                        .foregroundStyle(isOn ? Palette.ink : Palette.textPrimary)
                        .background(isOn ? Palette.volt : Palette.surfaceRaised, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(names[day - 1])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
