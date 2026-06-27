#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."
DEVICE_NAME="iPhone 17"

# Parse arguments
MODE="unit"
if [[ $# -gt 0 ]]; then
  case "$1" in
    ui|--ui)
      MODE="ui"
      ;;
    all|--all)
      MODE="all"
      ;;
    unit|--unit)
      MODE="unit"
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 [unit | ui | all]"
      exit 1
      ;;
  esac
fi

# Always run xcodegen to ensure target memberships are automatically updated
xcodegen generate

# Check if the device is already booted to save time
BOOTED_STATE=$(xcrun simctl list devices | grep "$DEVICE_NAME" | grep -o "Booted" || true)
if [[ -z "$BOOTED_STATE" ]]; then
  echo "Booting $DEVICE_NAME..."
  xcrun simctl boot "$DEVICE_NAME" 2>/dev/null || true
  xcrun simctl bootstatus "$DEVICE_NAME" -b
else
  echo "$DEVICE_NAME is already booted."
fi

# Determine xcodebuild test target constraints and parallel testing flags using arrays to prevent zsh argument splitting issues
TEST_TARGET_FLAG=()
PARALLEL_FLAGS=()
if [[ "$MODE" == "unit" ]]; then
  echo "Running only unit tests (TrinketTests)..."
  TEST_TARGET_FLAG=(-only-testing:TrinketTests)
elif [[ "$MODE" == "ui" ]]; then
  echo "Running only UI tests (TrinketUITests)..."
  TEST_TARGET_FLAG=(-only-testing:TrinketUITests)
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
else
  echo "Running all tests..."
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
fi

xcodebuild test \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -destination "platform=iOS Simulator,name=$DEVICE_NAME,OS=26.5" \
  "${TEST_TARGET_FLAG[@]}" \
  "${PARALLEL_FLAGS[@]}"
