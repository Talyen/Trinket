#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA_PATH="$PWD/.DerivedData"
RESULTS_DIR="$DERIVED_DATA_PATH/TestResults"
SCRIPT_DIR="$(dirname "$0")"

# shellcheck source=build-stamp.sh
source "$SCRIPT_DIR/build-stamp.sh"
# shellcheck source=build-inputs.sh
source "$SCRIPT_DIR/build-inputs.sh"

# Parse arguments
MODE="unit"
NO_BUILD=false
QUIET=true
VERBOSE=false
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
    smoke-full|--smoke-full)
      MODE="smoke-full"
      shift
      ;;
    no-build|--no-build)
      NO_BUILD=true
      shift
      ;;
    --quiet|quiet)
      QUIET=true
      shift
      ;;
    --verbose|verbose)
      VERBOSE=true
      QUIET=false
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
    echo "Usage: $0 [unit | ui | all | style | smoke | smoke-full] [--no-build] [TestClass[/testMethod] ...]"
    exit 1
  fi

  ./Scripts/format.sh --lint
  ./Scripts/lint.sh
  ./Scripts/check-ui-style.sh
  ./Scripts/check-platform-api-bans.sh
  exit 0
fi

mkdir -p "$RESULTS_DIR"
if [[ "$NO_BUILD" == "false" ]]; then
  prepare_generated_inputs "$RESULTS_DIR"
fi

# shellcheck source=ensure-simulator.sh
source "$SCRIPT_DIR/ensure-simulator.sh"

run_xcodebuild() {
  local attempt=1
  local max_attempts=2
  local exit_code=0
  local log_file="$RESULTS_DIR/xcodebuild.log"

  while (( attempt <= max_attempts )); do
    if [[ "$QUIET" == "true" ]]; then
      echo "Building and running tests... (raw log at .DerivedData/TestResults/xcodebuild.log)"
      set +e
      "$@" > "$log_file" 2>&1
      exit_code=$?
      set -e
      if [[ "$exit_code" -eq 0 ]]; then
        echo "Tests succeeded!"
        return 0
      fi
    elif command -v xcbeautify &>/dev/null; then
      set +e
      "$@" 2>&1 | tee "$log_file" | xcbeautify
      exit_code=${PIPESTATUS[0]}
      set -e
      if [[ "$exit_code" -eq 0 ]]; then
        return 0
      fi
    else
      set +e
      "$@" 2>&1 | tee "$log_file"
      exit_code=${PIPESTATUS[0]}
      set -e
      if [[ "$exit_code" -eq 0 ]]; then
        return 0
      fi
    fi

    if (( attempt < max_attempts )) && retryable_xcodebuild_infrastructure_failure "$exit_code" "$log_file"; then
      echo "xcodebuild infrastructure failure; re-preparing simulator and retrying once..." >&2
      if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
        echo "::warning title=Xcode infrastructure retry::Destination or simulator service failed; retrying once."
      fi
      ensure_test_simulator_logged force
      ((attempt++))
      continue
    fi

    # Print compilation errors if quiet and build failed (no result bundle generated)
    if [[ "$QUIET" == "true" && ! -d "$RESULT_BUNDLE_PATH" ]]; then
      echo -e "\n\033[1;31m=== BUILD/COMPILATION FAILURE ===\033[0m"
      grep -E -A 2 -i "error:|warning:|failed:" "$log_file" | head -n 40 || tail -n 40 "$log_file"
    fi

    return "$exit_code"
  done

  return "$exit_code"
}

retryable_xcodebuild_infrastructure_failure() {
  local exit_code="$1"
  local log_file="$2"

  [[ "$exit_code" -eq 70 ]] && return 0
  [[ -d "$RESULT_BUNDLE_PATH" ]] && return 1
  rg -qi \
    'Unable to boot|CoreSimulator|DTServiceHub|destination.*not available|no matching destination|launchd_sim|Simulator.*failed' \
    "$log_file"
}

xcresult_failed() {
  local result_path="$1"
  [[ -d "$result_path" ]] || return 1
  xcrun xcresulttool get test-results summary --path "$result_path" 2>/dev/null \
    | grep -Eq '"result" : "(Failed|unknown)"'
}

# Determine xcodebuild test target constraints using arrays to prevent zsh argument splitting issues
TEST_TARGET_FLAG=()
PARALLEL_FLAGS=()
if [[ "$MODE" == "unit" ]]; then
  TEST_TARGET_FLAG=(-testPlan Unit)
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
    TEST_TARGET_FLAG=(-testPlan Unit -only-testing:TrinketTests)
  fi
  ensure_test_simulator_logged
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
elif [[ "$MODE" == "smoke" ]]; then
  # Bare smoke = local canary (QuickSmoke). With targets, use full Smoke plan + filters.
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    TEST_TARGET_FLAG=(-testPlan Smoke)
    echo "Running targeted UI smoke tests via Smoke test plan..."
    for target in "${TARGETS[@]}"; do
      if [[ "$target" == TrinketUITests* ]]; then
        TEST_TARGET_FLAG+=("-only-testing:$target")
      else
        TEST_TARGET_FLAG+=("-only-testing:TrinketUITests/$target")
      fi
    done
  else
    TEST_TARGET_FLAG=(-testPlan QuickSmoke)
    echo "Running quick UI smoke canary via QuickSmoke test plan..."
  fi
  ensure_test_simulator_logged
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
elif [[ "$MODE" == "smoke-full" ]]; then
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    echo "Target filters are not supported for smoke-full mode; use smoke <Class> instead."
    echo "Usage: $0 [unit | ui | all | style | smoke | smoke-full] [--no-build] [TestClass[/testMethod] ...]"
    exit 1
  fi
  TEST_TARGET_FLAG=(-testPlan Smoke)
  echo "Running full UI smoke suite via Smoke test plan..."
  ensure_test_simulator_logged
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
elif [[ "$MODE" == "ui" ]]; then
  TEST_TARGET_FLAG=(-testPlan FullUI)
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
    TEST_TARGET_FLAG=(-testPlan FullUI -only-testing:TrinketUITests)
  fi
  ensure_test_simulator_logged
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
else
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    echo "Target filters are only supported for unit, ui, or smoke mode."
    echo "Usage: $0 [unit | ui | all | style | smoke | smoke-full] [--no-build] [TestClass[/testMethod] ...]"
    exit 1
  fi
  echo "Running all tests via Xcode Test Plan..."
  TEST_TARGET_FLAG=(-testPlan Integration)
  ensure_test_simulator_logged
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
fi

mkdir -p "$RESULTS_DIR"
RESULT_BUNDLE_PATH="$RESULTS_DIR/$MODE.xcresult"
rm -rf "$RESULT_BUNDLE_PATH"

ACTION="test"
RUN_FINGERPRINT="$MODE"
if [[ ${#TARGETS[@]} -gt 0 ]]; then
  for target in "${TARGETS[@]}"; do
    RUN_FINGERPRINT+="_$target"
  done
fi
BUILD_STAMP="$(build_stamp_path "$RESULTS_DIR" "$RUN_FINGERPRINT")"

record_timing() {
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    ./Scripts/test-timing.sh record \
      --mode "$MODE" \
      --wall "$TEST_WALL_SECONDS" \
      --xcresult "$RESULT_BUNDLE_PATH" \
      $([[ "$NO_BUILD" == "true" ]] && echo --no-build) \
      "${TARGETS[@]}"
  else
    ./Scripts/test-timing.sh record \
      --mode "$MODE" \
      --wall "$TEST_WALL_SECONDS" \
      --xcresult "$RESULT_BUNDLE_PATH" \
      $([[ "$NO_BUILD" == "true" ]] && echo --no-build)
  fi
}

assert_no_build_is_fresh() {
  echo "Running without building. This only reruns the previously built '$RUN_FINGERPRINT' test binary."

  local built_app="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Trinket.app"
  if [[ ! -d "$built_app" ]]; then
    echo "Built app is missing from DerivedData. Run without --no-build first." >&2
    exit 1
  fi

  assert_no_build_inputs_are_fresh "$BUILD_STAMP" "$RUN_FINGERPRINT"
}

if [[ "$NO_BUILD" == "true" ]]; then
  assert_no_build_is_fresh
  ACTION="test-without-building"
fi

run_package_tests() {
  local xcodebuild_action="$1"
  local packages=(TrinketCore TrinketContent BattleEngine TrinketPersistence TrinketDesignSystem)
  local failed=0
  local build_seconds=0
  local test_seconds=0
  local package
  local package_status
  local jobs
  local cpu_count

  # Shared DerivedData build.db cannot be written in parallel — build serially first
  # when this is a full `test` action, then always run package tests with --no-build.
  if [[ "$xcodebuild_action" != "test-without-building" ]]; then
    SECONDS=0
    for package in "${packages[@]}"; do
      echo "Building $package package tests..."
      package_status=0
      (
        cd "Packages/$package"
        xcodebuild build-for-testing \
          -scheme "$package" \
          -sdk iphonesimulator \
          -destination "$SIMULATOR_DESTINATION" \
          -derivedDataPath "$DERIVED_DATA_PATH"
      ) || package_status=$?
      if [[ "$package_status" -eq 0 ]]; then
        touch_build_stamp "$RESULTS_DIR" "package_$package"
      fi
      if [[ "$package_status" -ne 0 ]]; then
        failed=1
      fi
    done
    build_seconds=$SECONDS
    if [[ "$failed" -ne 0 ]]; then
      TEST_WALL_SECONDS=$((TEST_WALL_SECONDS + build_seconds))
      return "$failed"
    fi
  fi

  cpu_count="$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"
  jobs="$cpu_count"
  if [[ "$jobs" -gt ${#packages[@]} ]]; then
    jobs=${#packages[@]}
  fi
  if [[ "$jobs" -lt 1 ]]; then
    jobs=1
  fi

  echo "Running package tests in parallel (jobs=$jobs)..."
  SECONDS=0
  printf '%s\n' "${packages[@]}" | xargs -P "$jobs" -I{} bash -c '
    set -euo pipefail
    package="$1"
    destination="$2"
    quiet="$3"
    verbose="$4"
    package_args=(--no-build "$package" --destination "$destination")
    if [[ "$quiet" == "true" ]]; then
      package_args+=(--quiet)
    fi
    if [[ "$verbose" == "true" ]]; then
      package_args+=(--verbose)
    fi
    ./Scripts/test-package.sh "${package_args[@]}"
  ' _ {} "$SIMULATOR_DESTINATION" "$QUIET" "$VERBOSE" || failed=1
  test_seconds=$SECONDS

  TEST_WALL_SECONDS=$((TEST_WALL_SECONDS + build_seconds + test_seconds))
  return "$failed"
}

TEST_WALL_SECONDS=0
SECONDS=0

XCODEBUILD_EXIT_CODE=0
XCODEBUILD_ARGS=(
  "$ACTION"
  -project Trinket.xcodeproj
  -scheme Trinket
  -sdk iphonesimulator
  -destination "$SIMULATOR_DESTINATION"
  -derivedDataPath "$DERIVED_DATA_PATH"
  -resultBundlePath "$RESULT_BUNDLE_PATH"
)
if [[ ${#TEST_TARGET_FLAG[@]} -gt 0 ]]; then
  XCODEBUILD_ARGS+=("${TEST_TARGET_FLAG[@]}")
fi
if [[ ${#PARALLEL_FLAGS[@]} -gt 0 ]]; then
  XCODEBUILD_ARGS+=("${PARALLEL_FLAGS[@]}")
fi

run_xcodebuild xcodebuild "${XCODEBUILD_ARGS[@]}" || XCODEBUILD_EXIT_CODE=$?

TEST_WALL_SECONDS=$SECONDS

if xcresult_failed "$RESULT_BUNDLE_PATH"; then
  XCODEBUILD_EXIT_CODE=1
fi

if [[ "$XCODEBUILD_EXIT_CODE" -ne 0 ]]; then
  if [[ -d "$RESULT_BUNDLE_PATH" ]]; then
    ./Scripts/summarize-failures.py "$RESULT_BUNDLE_PATH"
    record_timing
    echo ""
    echo "Timing recorded. Hotspots: ./Scripts/test-timing.sh"
  fi
  exit "$XCODEBUILD_EXIT_CODE"
fi

if [[ "$MODE" == "unit" && ${#TARGETS[@]} -eq 0 ]]; then
  echo "Running package tests..."
  run_package_tests "$ACTION" || exit 1
fi

if [[ "$NO_BUILD" == "false" ]]; then
  touch "$BUILD_STAMP"
fi

if [[ -d "$RESULT_BUNDLE_PATH" ]]; then
  record_timing
  echo ""
  echo "Timing recorded. Hotspots: ./Scripts/test-timing.sh"
fi
