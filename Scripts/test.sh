#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."
DEVICE_NAME="iPhone 17 Pro"
DERIVED_DATA_PATH="$PWD/.DerivedData"
RESULTS_DIR="$DERIVED_DATA_PATH/TestResults"

# Parse arguments
MODE="unit"
NO_BUILD=false
USED_FAST_ALIAS=false
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
    smoke|--smoke)
      MODE="smoke"
      shift
      ;;
    no-build|--no-build)
      NO_BUILD=true
      shift
      ;;
    fast|--fast|-f)
      NO_BUILD=true
      USED_FAST_ALIAS=true
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
    echo "Usage: $0 [unit | ui | all | style | smoke] [--no-build] [TestClass[/testMethod] ...]"
    exit 1
  fi

  ./Scripts/format.sh --lint
  ./Scripts/lint.sh
  ./Scripts/check-ui-style.sh
  exit 0
fi

if [[ "$NO_BUILD" == "false" ]]; then
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
elif [[ "$MODE" == "smoke" ]]; then
  echo "Running smoke tests via Xcode Test Plan..."
  TEST_TARGET_FLAG=(-testPlan Smoke)
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
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
    echo "Usage: $0 [unit | ui | all | style | smoke] [--no-build] [TestClass[/testMethod] ...]"
    exit 1
  fi
  echo "Running all tests via Xcode Test Plan..."
  TEST_TARGET_FLAG=(-testPlan Integration)
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
fi

mkdir -p "$RESULTS_DIR"
RESULT_BUNDLE_PATH="$RESULTS_DIR/$MODE.xcresult"
rm -rf "$RESULT_BUNDLE_PATH"

ACTION="test"
RUN_FINGERPRINT="$MODE"
for target in "${TARGETS[@]}"; do
  RUN_FINGERPRINT+="_$target"
done
RUN_KEY="$(printf "%s" "$RUN_FINGERPRINT" | tr -c '[:alnum:]_.-' '_')"
BUILD_STAMP="$RESULTS_DIR/.last-build-$RUN_KEY.stamp"

assert_no_build_is_fresh() {
  if [[ "$USED_FAST_ALIAS" == "true" ]]; then
    echo "Warning: --fast is deprecated; use --no-build for test-without-building reruns." >&2
  fi

  echo "Running without building. This only reruns the previously built '$RUN_FINGERPRINT' test binary."

  if [[ ! -f "$BUILD_STAMP" ]]; then
    echo "No prior built test stamp found for '$RUN_FINGERPRINT'. Run without --no-build first." >&2
    exit 1
  fi

  local built_app="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Trinket.app"
  if [[ ! -d "$built_app" ]]; then
    echo "Built app is missing from DerivedData. Run without --no-build first." >&2
    exit 1
  fi

  local newer_files=()
  local source_roots=(Trinket TrinketTests TrinketUITests)
  local root
  for root in "${source_roots[@]}"; do
    if [[ -d "$root" ]]; then
      while IFS= read -r file; do
        newer_files+=("$file")
        if [[ ${#newer_files[@]} -ge 10 ]]; then
          break 2
        fi
      done < <(find "$root" -type f \( -name "*.swift" -o -name "*.plist" -o -name "*.xctestplan" \) -newer "$BUILD_STAMP" -print)
    fi
  done

  local project_files=(project.yml Package.resolved)
  local file
  for file in "${project_files[@]}"; do
    if [[ -f "$file" && "$file" -nt "$BUILD_STAMP" ]]; then
      newer_files+=("$file")
    fi
  done

  if [[ ${#newer_files[@]} -gt 0 ]]; then
    echo "--no-build refused because sources changed after the last built '$RUN_FINGERPRINT' test binary:" >&2
    for file in "${newer_files[@]}"; do
      echo "  $file" >&2
    done
    echo "Run without --no-build to rebuild app and test bundles." >&2
    exit 1
  fi
}

if [[ "$NO_BUILD" == "true" ]]; then
  assert_no_build_is_fresh
  ACTION="test-without-building"
fi

xcodebuild "$ACTION" \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -destination "platform=iOS Simulator,name=$DEVICE_NAME" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  "${TEST_TARGET_FLAG[@]}" \
  "${PARALLEL_FLAGS[@]}"

if [[ "$NO_BUILD" == "false" ]]; then
  touch "$BUILD_STAMP"
fi
