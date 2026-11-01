#!/usr/bin/env bash
# Picks the newest *stable* Xcode 26.x installed on the build machine
# (skips betas and release candidates) so builds match iOS 26 phones.
set -euo pipefail

xcode=$(ls -d /Applications/Xcode_26*.app 2>/dev/null \
  | grep -v -i -E 'beta|release_candidate|_rc' \
  | sort -V \
  | tail -1)

if [[ -z "${xcode}" ]]; then
  echo "No stable Xcode 26 found. Installed versions:" >&2
  ls -d /Applications/Xcode*.app >&2
  exit 1
fi

echo "Using ${xcode}"
sudo xcode-select -s "${xcode}"
xcodebuild -version
