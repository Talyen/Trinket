#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE_NAME="iPhone 17"
BUNDLE_ID="com.ryanmcintire.Trinket"
DERIVED_DATA_PATH="$PWD/.DerivedData"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Trinket.app"

xcodegen generate
xcodebuild build \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -destination "platform=iOS Simulator,name=$DEVICE_NAME,OS=26.5" \
  -derivedDataPath "$DERIVED_DATA_PATH"

xcrun simctl boot "$DEVICE_NAME" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_NAME" -b
DEVICE_UDID="$(xcrun simctl getenv "$DEVICE_NAME" SIMULATOR_UDID)"
open -a Simulator --args -CurrentDeviceUDID "$DEVICE_UDID"
xcrun simctl uninstall "$DEVICE_NAME" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$DEVICE_NAME" "$APP_PATH"
xcrun simctl launch "$DEVICE_NAME" "$BUNDLE_ID"
