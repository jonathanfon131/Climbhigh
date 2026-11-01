#!/usr/bin/env bash
# Usage: take-screenshots.sh <path to ClimbHigh.app built for simulator> <output folder>
# Boots an iPhone simulator, launches the app in demo mode on each tab, and saves PNGs.
set -euo pipefail
app="$1"; out="$2"
bundle="com.jonathanfon.climbhigh"
mkdir -p "$out"

device=$(xcrun simctl list devices available | grep -E "iPhone 17 \(" | head -1 | grep -oE "[0-9A-F-]{36}" || true)
if [[ -z "$device" ]]; then
  device=$(xcrun simctl list devices available | grep -E "iPhone" | head -1 | grep -oE "[0-9A-F-]{36}")
fi
echo "Simulator: $device"
xcrun simctl boot "$device" || true
xcrun simctl bootstatus "$device" -b
xcrun simctl ui "$device" appearance dark
xcrun simctl status_bar "$device" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 || true
xcrun simctl install "$device" "$app"

for tab in today reminders workout notes pip; do
  xcrun simctl terminate "$device" "$bundle" 2>/dev/null || true
  xcrun simctl launch "$device" "$bundle" -demo -tab "$tab"
  sleep 6
  xcrun simctl io "$device" screenshot "$out/$tab.png"
  echo "Saved $out/$tab.png"
done
