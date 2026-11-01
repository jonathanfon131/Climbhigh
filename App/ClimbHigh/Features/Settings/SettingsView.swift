import ClimbHighCore
import SwiftUI
import UniformTypeIdentifiers

/// Every setting in one screen: workout alerts, reminder defaults, Focus,
/// permissions, and backups.
struct SettingsView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(BackupService.self) private var backup
    @Environment(ReminderStore.self) private var reminders
    @Environment(\.storageWarning) private var storageWarning

    @State private var exportFile: BackupFile?
    @State private var showImporter = false
    @State private var backupMessage: String?
    @State private var newNudge = Date.now

    var body: some View {
        Form {
            if let storageWarning {
                Section { NoticeBanner(text: storageWarning, systemImage: "exclamationmark.triangle.fill", color: Palette.coral) }
            }

            workoutSection
            reminderDefaultsSection
            focusSection
            permissionsSection
            backupSection
            aboutSection
        }
        .navigationTitle("Settings")
        .screenBackground()
        .fileExporter(
            isPresented: Binding(get: { exportFile != nil }, set: { if !$0 { exportFile = nil } }),
            document: exportFile,
            contentType: .json,
            defaultFilename: BackupService.suggestedFileName()
        ) { result in
            switch result {
            case .success: backupMessage = "Backup saved."
            case let .failure(error): backupMessage = error.localizedDescription
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            importBackup(result)
        }
        .alert("Backup", isPresented: Binding(get: { backupMessage != nil }, set: { if !$0 { backupMessage = nil } })) {
            Button("OK") { backupMessage = nil }
        } message: {
            Text(backupMessage ?? "")
        }
    }

    private static let leadTimeChoices = [
        LeadTime(amount: 15, unit: .minutes), LeadTime(amount: 1, unit: .hours), LeadTime(amount: 2, unit: .hours),
        LeadTime(amount: 1, unit: .days), LeadTime(amount: 3, unit: .days), LeadTime(amount: 1, unit: .weeks)
    ]

    // MARK: Sections

    private var workoutSection: some View {
        Section {
            NavigationLink {
                RestTimesEditor()
            } label: {
                HStack {
                    Label("Rest times", systemImage: "timer")
                    Spacer()
                    Text(SetIntensity.allCases.map { Clock.format(TimeInterval(settings.settings.restPresets.seconds(for: $0))) }.joined(separator: " · "))
                        .foregroundStyle(Palette.textSecondary)
                        .monospacedDigit()
                }
            }

            Picker("When rest ends", selection: settings.binding(\.restAlertStyle)) {
                ForEach(RestAlertStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }

            if settings.settings.restAlertStyle == .buzz {
                Stepper("Buzz every \(settings.settings.buzzEverySeconds) s", value: settings.binding(\.buzzEverySeconds), in: 3...30)
                Stepper("For up to \(settings.settings.buzzForSeconds) s", value: settings.binding(\.buzzForSeconds), in: 15...180, step: 15)
            }
            Toggle("Vibrate while the app is open", isOn: settings.binding(\.vibrateInApp))
        } header: {
            Text("Workout")
        } footer: {
            Text(settings.settings.restAlertStyle.explanation)
        }
    }

    private var reminderDefaultsSection: some View {
        Section {
            Toggle("Ring as an alarm when due", isOn: settings.binding(\.defaultRingsAlarm))

            ForEach(settings.settings.defaultNudgeTimes, id: \.self) { time in
                Text("Remind me at \(time.label)")
            }
            .onDelete { offsets in
                settings.update { $0.defaultNudgeTimes.remove(atOffsets: offsets) }
            }
            if settings.settings.defaultNudgeTimes.count < 6 {
                HStack {
                    DatePicker("Add a time", selection: $newNudge, displayedComponents: .hourAndMinute)
                    Button("Add") {
                        let time = TimeOfDay(of: newNudge, calendar: .current)
                        settings.update { current in
                            if !current.defaultNudgeTimes.contains(time) {
                                current.defaultNudgeTimes = (current.defaultNudgeTimes + [time]).sorted()
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }

            ForEach(settings.settings.defaultLeadTimes) { lead in
                Text("Heads-up \(lead.label)")
            }
            .onDelete { offsets in
                settings.update { $0.defaultLeadTimes.remove(atOffsets: offsets) }
            }
            Menu("Add a heads-up") {
                ForEach(Self.leadTimeChoices) { choice in
                    Button(choice.label) {
                        settings.update { $0.defaultLeadTimes.append(LeadTime(amount: choice.amount, unit: choice.unit)) }
                    }
                }
            }
        } header: {
            Text("New reminder defaults")
        } footer: {
            Text("Used for every new reminder, including ones you create by voice. You can change them per reminder. Swipe left to remove.")
        }
    }

    private var focusSection: some View {
        Section {
            Toggle("Turn on Focus during workouts", isOn: settings.binding(\.focusAutomationEnabled))
            NavigationLink("Set it up (1 minute)") { FocusSetupView() }
        } header: {
            Text("Do Not Disturb")
        } footer: {
            Text("iPhone apps can't switch Focus on by themselves, so Climb High runs two tiny Shortcuts you create once.")
        }
    }

    private var permissionsSection: some View {
        Section("Permissions & AI") {
            PermissionsStatusView()
        }
    }

    private var backupSection: some View {
        Section {
            Button {
                do {
                    exportFile = try backup.makeBackup()
                } catch {
                    backupMessage = "Couldn't create the backup: \(error.localizedDescription)"
                }
            } label: {
                Label("Export backup", systemImage: "square.and.arrow.up")
            }
            Button {
                showImporter = true
            } label: {
                Label("Restore from backup", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Backup")
        } footer: {
            Text("Everything lives only on this iPhone. Export a backup to Files or iCloud Drive now and then — especially before reinstalling the app.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
            Link("Rest-time research (Frontiers, 2024)", destination: URL(string: "https://www.frontiersin.org/articles/10.3389/fspor.2024.1429789/full")!)
            Link("Rest-time research (Schoenfeld, 2016)", destination: URL(string: "https://pubmed.ncbi.nlm.nih.gov/26605807/")!)
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        switch result {
        case let .success(url):
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let imported = try backup.restore(from: data)
                reminders.refreshAlerts()
                backupMessage = imported.summary
            } catch {
                backupMessage = "Couldn't restore: \(error.localizedDescription)"
            }
        case let .failure(error):
            backupMessage = error.localizedDescription
        }
    }
}
