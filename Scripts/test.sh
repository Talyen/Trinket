#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."
DEVICE_NAME="iPhone 17"

xcodegen generate
xcrun simctl boot "$DEVICE_NAME" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_NAME" -b
xcodebuild test \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -destination "platform=iOS Simulator,name=$DEVICE_NAME,OS=26.5"
