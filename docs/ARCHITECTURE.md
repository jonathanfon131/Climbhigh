# Architecture

Climb High is built in three layers. Each layer may only depend on the layer below it.

```
┌──────────────────────────────────────────────────────────────┐
│ Features/ (SwiftUI screens)                                  │
│   read data with @Query · call Stores to change anything     │
├──────────────────────────────────────────────────────────────┤
│ Stores/ (ReminderStore, NoteStore, WorkoutController, …)     │
│   the ONLY code that writes data · keeps alerts in sync      │
│ Services/ (AlarmService, NotificationService, SpeechService, │
│   NoteAIService, AssistantController, BackupService, …)      │
│   thin wrappers around iOS frameworks                        │
├──────────────────────────────────────────────────────────────┤
│ ClimbHighCore (Swift package)                                │
│   pure logic: no UI, no database, no iOS frameworks · tested │
└──────────────────────────────────────────────────────────────┘
```

`App/AppContainer.swift` builds every store and service exactly once and connects them. If you want to know "who talks to whom", that file is the map.

## The rules

1. **Logic lives in ClimbHighCore.** When reminders fire, how repeats work, rest math, how "tomorrow at 5" is parsed: all of it is plain Swift with unit tests. If something can be tested without an iPhone, it belongs there.
2. **Screens read, stores write.** Views use SwiftData `@Query` for live lists. Every change goes through a store method (`reminders.markDone(…)`, `notes.applyAIEdit(…)`, `workout.finishSet(…)`). Stores save and then re-plan alerts, so alarms can't drift out of sync with the data.
3. **Re-plan, don't patch.** `ReminderAlertScheduler` rebuilds the full alert plan every time (`AlertPlanner` is a pure function). Calling it twice is harmless. That's simpler and safer than tracking individual changes.
4. **Times come from dates, not timers.** A rest is stored as `startedAt + duration`. The countdown is always computed from the clock, so closing or killing the app mid-rest is fine.
5. **AI never changes your data silently.** Note edits and plans are shown first. Approving saves the old version to History, so it can be undone.
6. **Fail soft.** If alarms aren't allowed, the rest timer falls back to Buzz notifications and says so. If the database can't open, the app runs in memory and warns you. If AI is off, voice commands still work through the offline parser.

## How the main features work

### Reminders
```
ReminderEditorView ─▶ ReminderStore.create/update ─▶ SwiftData
                                   │
                                   ▼
                     ReminderAlertScheduler.reschedule
                                   │
                    AlertPlanner (Core) → [PlannedAlert]
                       │                          │
          due + "Ring as alarm"            everything else
                       ▼                          ▼
                 AlarmService            NotificationService
               (AlarmKit alarm)       (heads-ups, nudges; 48 max)
```
- iOS keeps at most **64** scheduled notifications per app. Reminders get 48, and the rest are kept free for workout buzzes. Only the next 30 days are scheduled. The plan is topped up whenever the app opens and during background refresh.
- Notification buttons (**Done**, **Snooze 10 min**) are handled in `AppContainer.handleNotification`.

### Workout rest timer
```
IntensityTile tap ─▶ WorkoutController.finishSet(.heavy)
     logs WorkoutSetEntry · creates RestPeriod · saves state to disk
     ├─ Alarm style ▶ AlarmService.startRestTimer (AlarmKit countdown → rings until stopped)
     └─ Buzz style  ▶ NotificationService.scheduleRestBuzz (notification every N s)
Rest ends ─▶ alarm "Start set" button ─▶ StartNextSetIntent ─▶ WorkoutController.startNextSet()
```
AlarmKit requires the widget extension (`App/ClimbHighWidgets`) for countdowns. It draws the Lock Screen and Dynamic Island timer.

### Assistant and voice
```
mic ─▶ SpeechService (on-device) ─▶ AssistantController.send(text)
          ├─ CommandParser (Core, offline): reminders, notes, rest, "what's next"
          └─ otherwise Apple's on-device model, with tools createReminder/createNote
```

### Notes AI
`NoteAIService.review` asks the on-device model for a `NoteReview`: opinion, issues, additions, next steps, questions, and an improved version. `@Generable` means the model fills in exactly those typed fields. **Discuss** opens a chat about the note, and **Make plan** turns that chat into steps you can add to the note.

### Daily verse and streaks
```
scripts/build_daily_verses.py ─▶ daily-verses.json (414 verses, exact BSB text)
VerseLibrary (Core): day → verse (same all day, next one tomorrow, wraps after the list)
"I read it" (card or notification button) ─▶ FaithStore.markTodayRead ─▶ VerseRead row
ReadingStreak (Core): current / best / total from the set of read days
FaithStore.refreshReminders ─▶ next 7 mornings' notifications, each with that day's verse
```
The streak survives until midnight: if you haven't read today yet, yesterday's streak still counts.

### Pip (the assistant's character)
`DesignSystem/PipView.swift` draws Pip from plain shapes and animates from the clock (`TimelineView`). It has five moods: idle, thinking, listening, happy and sleepy. Screens choose the mood from state (mic on → listening, AI working → thinking, just did something → happy, AI off → sleepy). Reduce Motion freezes it.

## Decisions (and why)

| Decision | Why |
|---|---|
| Native SwiftUI, not a web app | Alarms that ring through Silent/Focus, vibration, Lock Screen timers and on-device AI aren't available to web apps on iPhone. |
| AlarmKit for the rest timer | The only API that keeps ringing until you act, even with the app closed and Focus on. |
| Focus via Shortcuts | iOS has no API for apps to turn on Do Not Disturb. Running a user-made shortcut is Apple's supported route. |
| Apple Foundation Models for AI | Free, private, offline, built into iOS 26. No API keys or servers to maintain. |
| Offline `CommandParser` before the AI | Common commands work instantly and still work if Apple Intelligence is off. |
| Schedules stored as JSON inside SwiftData | Same format as backups, versionable, readable, and tolerant of new fields. |
| XcodeGen `project.yml` | A 100-line readable file instead of a huge generated project file. Builds reproducibly in CI without a Mac. |
| App in Swift 5 mode, Core in Swift 6 strict mode | Core is pure value types, so strict concurrency is free there. The app talks to older callback-based Apple APIs; isolation is still explicit (`@MainActor` stores, `nonisolated` callbacks). |
| Bundled Berean Standard Bible text | Public domain, so it can ship in the app. Modern English. The wording is generated from the publisher's files, never typed by hand. Works offline. |
| Data on the phone only + JSON backups | No account or server to secure or pay for. Backups to Files/iCloud Drive cover phone changes. |

## Adding a feature (checklist)

1. Put the rules in ClimbHighCore with tests.
2. If it stores data, add fields to `Persistence/Models.swift` (with defaults) **and** to the backup records in Core.
3. Add store methods for every change. Views never write to the database directly.
4. Build the screen from `DesignSystem` components (`card()`, `PillButtonStyle`, `BigTitle`, …).
5. Keep the accessibility bar: 44 pt tap targets, Dynamic Type, VoiceOver labels on icon buttons, and contrast ≥ 4.5:1.
6. Push and confirm the **Build** workflow is green. Note anything only a real iPhone can confirm in `docs/CHANGELOG.md`.
