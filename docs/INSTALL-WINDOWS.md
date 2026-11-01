# Installing Climb High on your iPhone (Windows PC, no Mac)

GitHub builds the app for you on a Mac in the cloud. You download the finished file and put it on your phone with **Sideloadly**, a free Windows tool that signs apps with your Apple ID.

## One-time setup (about 15 minutes)

1. **Get Apple's own iTunes and iCloud for Windows.** Sideloadly needs the versions downloaded from apple.com, *not* the Microsoft Store ones. If you have the Store versions, uninstall them first. Check [sideloadly.io](https://sideloadly.io) for the current links.
2. **Install Sideloadly** from [sideloadly.io](https://sideloadly.io).
3. **Turn on Developer Mode on the iPhone:** Settings → Privacy & Security → Developer Mode → On. The phone restarts.

## Install (and update) the app

1. On GitHub, open this repo → **Actions** → the latest green **Build** run → under **Artifacts**, download **ClimbHigh-ipa**. Unzip it to get `ClimbHigh.ipa`.
2. Plug the iPhone into the PC with a cable and tap **Trust** on the phone.
3. Open Sideloadly, drag `ClimbHigh.ipa` into it, enter your Apple ID, and press **Start**. Enter the 2-factor code if asked.
4. On the iPhone: Settings → General → **VPN & Device Management** → your Apple ID → **Trust**.
5. Open Climb High. Allow **Notifications**, **Alarms**, and (when you first tap the mic) **Microphone** and **Speech Recognition**.

## The 7-day limit (free Apple ID)

Apps signed with a free Apple ID stop opening after **7 days**. To renew, run Sideloadly again with the same `.ipa`. Installing over the existing app **keeps your data**. Sideloadly can refresh automatically over Wi-Fi while your PC is on. See its site for that setup.

> **Don't delete the app before reinstalling.** Deleting it erases its data. Export a backup first if you ever need to (Settings → Backup → Export).

## Want no 7-day limit?

Apple's Developer Program costs **$99/year**. With it, the app lasts a year per install and can be delivered through **TestFlight** (no cable, no Sideloadly). The build workflow can be extended to upload to TestFlight automatically. Ask if you want that.

## Safety notes

- Sideloadly is a third-party tool. It sends your Apple ID login to Apple to create a signing certificate. If that worries you, create a **separate free Apple ID** just for signing apps.
- Only install `.ipa` files from your own repo's Actions runs.

## Troubleshooting

| Problem | Fix |
|---|---|
| "Untrusted Developer" | Settings → General → VPN & Device Management → Trust. |
| App won't open after a week | Re-run Sideloadly (7-day limit above). |
| Sideloadly can't see the phone | Use Apple's iTunes (not the Microsoft Store one), unlock the phone, tap Trust. |
| No alarm sound at the end of a rest | iPhone Settings → Climb High → make sure **Alarms** is on. Or switch to Buzz in the app's Settings. |
| AI says it's unavailable | iPhone Settings → Apple Intelligence & Siri → turn it on and let it finish downloading. |
