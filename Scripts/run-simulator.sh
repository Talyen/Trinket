#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="com.ryanmcintire.Trinket"
DERIVED_DATA_PATH="$PWD/.DerivedData"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Trinket.app"

# shellcheck source=ensure-simulator.sh
source ./Scripts/ensure-simulator.sh
ensure_test_simulator

xcodegen generate
xcodebuild build \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -destination "$SIMULATOR_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH"

# Default to dark mode
xcrun simctl spawn "$SIMULATOR_UDID" defaults write com.apple.UIKit UIUserInterfaceStyle -int 2 2>/dev/null || true
xcrun simctl spawn "$SIMULATOR_UDID" killall SpringBoard 2>/dev/null || true
sleep 1
open -a Simulator --args -CurrentDeviceUDID "$SIMULATOR_UDID"
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
# Installing a normal app bundle replaces the XCTest-installed app container, so
# invalidate test-without-building stamps that depend on that simulator state.
rm -f "$DERIVED_DATA_PATH"/TestResults/.last-build-*.stamp(N) 2>/dev/null || true
xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" -- -theme dark
