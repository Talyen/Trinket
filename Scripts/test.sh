#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."
DEVICE_NAME="iPhone 17 Pro"
DERIVED_DATA_PATH="$PWD/.DerivedData"
RESULTS_DIR="$DERIVED_DATA_PATH/TestResults"

# Parse arguments
MODE="unit"
FAST=false
TARGETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    ui|--ui)
      MODE="ui"
      shift
      ;;
    all|--all)
      MODE="all"
      shift
      ;;
    style|--style)
      MODE="style"
      shift
      ;;
    unit|--unit)
      MODE="unit"
      shift
      ;;
    fast|--fast|-f)
      FAST=true
      shift
      ;;
    *)
      TARGETS+=("$1")
      shift
      ;;
  esac
done

if [[ "$MODE" == "style" ]]; then
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    echo "Target filters are not supported for style mode."
    echo "Usage: $0 [unit | ui | all | style] [TestClass[/testMethod] ...]"
    exit 1
  fi

  ./Scripts/check-ui-style.sh
  exit 0
fi

if [[ "$FAST" == "false" ]]; then
  # Always run xcodegen to ensure target memberships are automatically updated
  xcodegen generate
fi

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
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    echo "Running targeted unit tests..."
    for target in "${TARGETS[@]}"; do
      if [[ "$target" == TrinketTests* ]]; then
        TEST_TARGET_FLAG+=("-only-testing:$target")
      else
        TEST_TARGET_FLAG+=("-only-testing:TrinketTests/$target")
      fi
    done
  else
    echo "Running only unit tests (TrinketTests)..."
    TEST_TARGET_FLAG=(-only-testing:TrinketTests)
  fi
elif [[ "$MODE" == "ui" ]]; then
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    echo "Running targeted UI tests..."
    for target in "${TARGETS[@]}"; do
      if [[ "$target" == TrinketUITests* ]]; then
        TEST_TARGET_FLAG+=("-only-testing:$target")
      else
        TEST_TARGET_FLAG+=("-only-testing:TrinketUITests/$target")
      fi
    done
  else
    echo "Running only UI tests (TrinketUITests)..."
    TEST_TARGET_FLAG=(-only-testing:TrinketUITests)
  fi
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
else
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    echo "Target filters are only supported for unit or ui mode."
    echo "Usage: $0 [unit | ui | all | style] [TestClass[/testMethod] ...]"
    exit 1
  fi
  echo "Running all tests..."
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
fi

mkdir -p "$RESULTS_DIR"
RESULT_BUNDLE_PATH="$RESULTS_DIR/$MODE.xcresult"
rm -rf "$RESULT_BUNDLE_PATH"

ACTION="test"
if [[ "$FAST" == "true" ]]; then
  ACTION="test-without-building"
fi

xcodebuild "$ACTION" \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -destination "platform=iOS Simulator,name=$DEVICE_NAME,OS=26.5" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  "${TEST_TARGET_FLAG[@]}" \
  "${PARALLEL_FLAGS[@]}"
