#!/bin/bash
# Builds the app for the simulator and saves App Store screenshots from the largest iPhone
# (6.9" display, the size App Store Connect requires) into the given folder.
set -euo pipefail
OUT=${1:-fastlane/screenshots/en-US}
mkdir -p "$OUT" && OUT=$(cd "$OUT" && pwd)
cd "$(dirname "$0")/.."

xcodebuild -project ColorMatch.xcodeproj -target ColorMatch -sdk iphonesimulator -configuration Release \
  CODE_SIGNING_ALLOWED=NO SYMROOT="$PWD/build/sim" build | tail -n 5
APP=build/sim/Release-iphonesimulator/ColorMatch.app

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
phones = [d for runtime, ds in sorted(devices.items(), reverse=True) if "iOS" in runtime for d in ds]
print([d for d in phones if d["name"].startswith("iPhone") and "Pro Max" in d["name"]][0]["udid"])
')
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 || true
xcrun simctl install "$UDID" "$APP"

rm -rf "$OUT" && mkdir -p "$OUT"
shoot() {
  name=$1; shift
  xcrun simctl terminate "$UDID" com.arochat9.ColorMatch 2>/dev/null || true
  xcrun simctl launch "$UDID" com.arochat9.ColorMatch "$@"
  sleep 8
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png"
}
xcrun simctl ui "$UDID" appearance light
shoot 1-mixing -demo mixing -seed 3
shoot 2-result -demo submitted -seed 3
shoot 3-named-goal -demo mixing -seed 5 -goalMode named
shoot 4-library -demo library -seed 1
xcrun simctl ui "$UDID" appearance dark
shoot 5-result-dark -demo submitted -seed 8
xcrun simctl shutdown "$UDID" || true
ls -la "$OUT"
