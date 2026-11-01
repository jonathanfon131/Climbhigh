# Climb High

A personal iPhone app (iOS 26.1+) for three things:

1. **Reminders that actually get your attention.** Early heads-ups (any number of minutes, hours, days or weeks before), a real alarm at the due time that rings through Silent and Focus, and extra reminders at times you choose on the day until you tap Done.
2. **Workout mode.** Tap Light, Heavy or Failure after a set. Use your phone while you rest. When time's up, the phone rings and vibrates until you tap **Start set**. Can switch on Do Not Disturb automatically.
3. **Notes and an on-device assistant.** Speak or type reminders and notes. The AI reviews your notes: its opinion, what to fix, what to add, next steps, and questions. Edits are only applied when you tap Approve. Everything runs on the iPhone, with no accounts and no servers.

## Install it on your iPhone (Windows PC)

See **[docs/INSTALL-WINDOWS.md](docs/INSTALL-WINDOWS.md)**. Short version: download `ClimbHigh.ipa` from the latest successful **Build** run under the repo's Actions tab, then install it with Sideloadly.

## How the code is organized

```
Packages/ClimbHighCore/     The app's rules: pure Swift, no UI, fully unit-tested
  Reminders/                When reminders are due and which alerts to schedule
  Workout/                  Rest presets, rest-timer math, workout totals
  Assistant/                Understands "remind me to … tomorrow at 5" without AI
  Settings/ Backup/         Settings and the backup file format
App/ClimbHigh/              The iPhone app
  App/                      Entry point + AppContainer (wires everything together)
  Persistence/              Database tables (SwiftData)
  Stores/                   The only code that changes data
  Services/                 Talks to iOS: alarms, notifications, speech, AI, backups
  Intents/                  Siri / Shortcuts / alarm-button actions
  Features/                 Screens, one folder per tab
  DesignSystem/             Colors, type, buttons, cards — the whole look
App/ClimbHighWidgets/       Lock Screen + Dynamic Island countdown (needed by AlarmKit)
App/Shared/                 Code used by both the app and the widget
project.yml                 Xcode project definition (XcodeGen)
.github/workflows/build.yml Builds + tests on GitHub's Macs
```

Read **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** next. It explains how data flows through the app and the rules the code follows.

## Docs

| Doc | What's in it |
|---|---|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | Layers, data flow, key decisions, how to add a feature |
| [INSTALL-WINDOWS.md](docs/INSTALL-WINDOWS.md) | Getting the app onto your iPhone without a Mac |
| [FOCUS-SETUP.md](docs/FOCUS-SETUP.md) | One-time setup so workouts turn on Do Not Disturb |
| [REST-TIMES.md](docs/REST-TIMES.md) | The research behind the default rest times |
| [CHANGELOG.md](docs/CHANGELOG.md) | What's been verified vs. what still needs testing on a real iPhone |

## Developing

- **Logic changes** go in `Packages/ClimbHighCore` with a test. Run `swift test --package-path Packages/ClimbHighCore` on a Mac, or push and let CI run it.
- **App changes**: on a Mac, run `brew install xcodegen && xcodegen generate`, then open `ClimbHigh.xcodeproj`. Without a Mac, push to `main` and check the **Build** workflow.
- Never edit `ClimbHigh.xcodeproj` directly. It's generated from `project.yml`.
