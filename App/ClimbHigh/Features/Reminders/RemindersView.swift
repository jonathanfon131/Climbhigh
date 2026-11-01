import ClimbHighCore
import SwiftData
import SwiftUI

/// All reminders, grouped Overdue / Today / Upcoming / Done.
/// Swipe right = done, swipe left = delete, tap = edit.
struct RemindersView: View {
    @Environment(ReminderStore.self) private var store
    @Query(sort: \Reminder.createdAt) private var reminders: [Reminder]
    @State private var editorTarget: EditorTarget?

    enum EditorTarget: Identifiable {
        case new
        case existing(Reminder)

        var id: String {
            switch self {
            case .new: "new"
            case let .existing(reminder): reminder.id.uuidString
            }
        }
    }

    var body: some View {
        // Reading `reminders` ties this view to database changes.
        let items = reminders.isEmpty ? [] : store.agenda()

        List {
            Section {
                BigTitle(text: "Reminders", eyebrow: "\(items.filter { $0.entry.section != .done }.count) open")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            if items.isEmpty {
                Section {
                    EmptyStateView(systemImage: "bell.badge", title: "Nothing on deck", message: "Tap + to add a reminder, or tell the Assistant: “Remind me to pay rent on the 1st at 9”.")
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }

            ForEach(AgendaSection.allCases, id: \.self) { section in
                let rows = items.filter { $0.entry.section == section }
                if !rows.isEmpty {
                    Section {
                        ForEach(rows) { item in
                            ReminderRow(reminder: item.reminder, entry: item.entry)
                                .contentShape(Rectangle())
                                .onTapGesture { editorTarget = .existing(item.reminder) }
                                .swipeActions(edge: .leading) {
                                    if section == .done {
                                        Button("Reopen") { store.reopen(item.reminder) }
                                            .tint(Palette.sky)
                                    } else {
                                        Button("Done") { store.markDone(item.reminder) }
                                            .tint(Palette.accent)
                                    }
                                }
                                .swipeActions(edge: .trailing) {
                                    Button("Delete", role: .destructive) { store.delete(item.reminder) }
                                }
                                .listRowBackground(Palette.surface)
                        }
                    } header: {
                        Text(section.rawValue)
                            .font(.headline)
                            .foregroundStyle(section == .overdue ? Palette.coral : Palette.textSecondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .screenBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorTarget = .new
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .accessibilityLabel("New reminder")
                }
            }
        }
        .sheet(item: $editorTarget) { target in
            NavigationStack {
                switch target {
                case .new: ReminderEditorView(reminder: nil)
                case let .existing(reminder): ReminderEditorView(reminder: reminder)
                }
            }
        }
    }
}

struct ReminderRow: View {
    let reminder: Reminder
    let entry: AgendaEntry

    var body: some View {
        let schedule = reminder.schedule
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(reminder.title)
                    .font(.headline)
                    .foregroundStyle(entry.section == .done ? Palette.textSecondary : Palette.textPrimary)
                    .strikethrough(entry.section == .done)
                Spacer()
                Text(ReminderFormatting.when(entry.occurrence, section: entry.section))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(entry.section == .overdue ? Palette.coral : Palette.textSecondary)
            }
            HStack(spacing: 6) {
                if schedule.repeatRule.isRepeating {
                    Chip(text: schedule.repeatRule.summary, systemImage: "repeat")
                }
                if schedule.ringsAlarm {
                    Chip(text: "Alarm", systemImage: "alarm.fill", color: Palette.volt, foreground: Palette.ink)
                }
                if !schedule.leadTimes.isEmpty {
                    Chip(text: "\(schedule.leadTimes.count) heads-up", systemImage: "bell")
                }
                if !schedule.dayOfNudges.isEmpty {
                    Chip(text: "\(schedule.dayOfNudges.count)× on the day", systemImage: "arrow.clockwise")
                }
            }
            .lineLimit(1)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

enum ReminderFormatting {
    /// "Today 5:00 PM", "Tomorrow 9:00 AM", "Fri, Nov 6 · 9:00 AM", "Done".
    static func when(_ date: Date?, section: AgendaSection) -> String {
        guard let date else { return "Done" }
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return "Today \(time)" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow \(time)" }
        if calendar.isDateInYesterday(date) { return "Yesterday \(time)" }
        return "\(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) · \(time)"
    }
}
