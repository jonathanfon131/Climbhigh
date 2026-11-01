import SwiftUI

/// Step-by-step guide for the two Focus shortcuts, with a test button.
struct FocusSetupView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.focusService) private var focus

    var body: some View {
        Form {
            Section {
                Text("iOS doesn't let any app turn on Do Not Disturb by itself. Shortcuts can — so you make two tiny shortcuts once, and Climb High runs them when a workout starts and ends.")
                    .foregroundStyle(Palette.textSecondary)
            }

            Section("1 · Make the “on” shortcut") {
                Step(number: 1, text: "Open the Shortcuts app → tap **+**.")
                Step(number: 2, text: "Add the action **Set Focus**. Choose **Do Not Disturb** (or Fitness) and **Turn On**.")
                Step(number: 3, text: "Name the shortcut exactly: **\(settings.settings.focusOnShortcutName)**")
            }

            Section("2 · Make the “off” shortcut") {
                Step(number: 1, text: "Tap **+** again → **Set Focus** → same Focus → **Turn Off**.")
                Step(number: 2, text: "Name it exactly: **\(settings.settings.focusOffShortcutName)**")
            }

            Section {
                Step(number: 1, text: "iPhone Settings → **Focus** → Do Not Disturb → **Apps** → add **Climb High**, so your rest alerts still come through.")
                Step(number: 2, text: "Turn on **Turn on Focus during workouts** in Climb High Settings.")
            } header: {
                Text("3 · Let Climb High through")
            } footer: {
                Text("Alarms ring through Focus anyway; this step matters if you use Buzz mode.")
            }

            Section("Shortcut names") {
                TextField("On shortcut", text: settings.binding(\.focusOnShortcutName))
                TextField("Off shortcut", text: settings.binding(\.focusOffShortcutName))
            }

            Section {
                Button("Open Shortcuts") { focus?.openShortcutsApp() }
                Button("Test: turn Focus on") { focus?.runShortcut(named: settings.settings.focusOnShortcutName) }
                Button("Test: turn Focus off") { focus?.runShortcut(named: settings.settings.focusOffShortcutName) }
            } footer: {
                Text("Tip: on iPhone 17 you can also put a “heavy set” rest on the Action Button — Settings → Action Button → Shortcut → Climb High.")
            }
        }
        .navigationTitle("Focus setup")
        .navigationBarTitleDisplayMode(.inline)
        .screenBackground()
    }
}

private struct Step: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(Palette.ink)
                .frame(width: 26, height: 26)
                .background(Palette.volt, in: Circle())
            Text(LocalizedStringKey(text)) // renders the **bold** markdown
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
