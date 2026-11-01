# Changelog & verification log

Following the playbook rule: keep "checked and fine" separate from "assumed fine".

## 1.0.0 — 2026-11-01

### Verified
- **Core logic: 39 unit tests pass** on GitHub's macOS 26 runner (reminder occurrences incl. month-end and daylight-saving, alert planning, agenda sections, rest math, workout totals, date/command parsing, settings/backup compatibility).
- **App compiles** for iOS with Xcode 26.6 on CI, and an unsigned `ClimbHigh.ipa` is produced (see the Build workflow). _(pending first green build)_
- AlarmKit, Foundation Models and notification API usage was checked against Apple's current documentation (Nov 2026).

### Needs a real iPhone to confirm (not yet tested on device)
- [ ] Rest alarm rings through Silent + Focus and the **Start set** button ends the rest (AlarmKit).
- [ ] Lock Screen / Dynamic Island countdown appears during rest.
- [ ] Reminder alarm at due time; **Snooze 10m** re-rings.
- [ ] Heads-up and day-of notifications arrive; **Done** / **Snooze** buttons work from the banner.
- [ ] Buzz mode repeats and stops when you tap Start set.
- [ ] Focus shortcuts run and return to the app.
- [ ] Voice: mic → transcript → reminder/note created.
- [ ] Notes AI review quality and speed on iPhone 17 (on-device model).
- [ ] Backup export → delete data → import restores everything.
- [ ] Sideloadly install with a free Apple ID (including the widget extension).

### Known limits
- iOS allows 64 scheduled notifications per app. Climb High schedules the next 30 days (up to 48 reminder alerts), topped up on app open and background refresh. If you have lots of reminders and don't open the app for weeks, far-off alerts are added later.
- The free Apple ID signing limit means reinstalling every 7 days (see INSTALL-WINDOWS.md).
- The failure-set rest default is an estimate (see REST-TIMES.md).
