#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

DEVICE_NAME="iPhone 17 Pro"
BUNDLE_ID="com.ryanmcintire.Trinket"
DERIVED_DATA_PATH="$PWD/.DerivedData"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Trinket.app"

xcodegen generate
xcodebuild build \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -destination "platform=iOS Simulator,name=$DEVICE_NAME" \
  -derivedDataPath "$DERIVED_DATA_PATH"

xcrun simctl boot "$DEVICE_NAME" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_NAME" -b
# Default to dark mode
xcrun simctl spawn "$DEVICE_NAME" defaults write NSGlobalDomain AppleInterfaceStyle Dark 2>/dev/null || true
xcrun simctl spawn "$DEVICE_NAME" killall SpringBoard 2>/dev/null || true
sleep 1
DEVICE_UDID="$(xcrun simctl getenv "$DEVICE_NAME" SIMULATOR_UDID)"
open -a Simulator --args -CurrentDeviceUDID "$DEVICE_UDID"
xcrun simctl uninstall "$DEVICE_NAME" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$DEVICE_NAME" "$APP_PATH"
xcrun simctl launch "$DEVICE_NAME" "$BUNDLE_ID"
