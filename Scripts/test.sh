#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
SCRIPT_DIR="$(dirname "$0")"

# shellcheck source=run-env.sh
source "$SCRIPT_DIR/run-env.sh"
trinket_run_env_init
trinket_run_env_print

# shellcheck source=build-stamp.sh
source "$SCRIPT_DIR/build-stamp.sh"
# shellcheck source=build-inputs.sh
source "$SCRIPT_DIR/build-inputs.sh"
# shellcheck source=xcode-runner.sh
source "$SCRIPT_DIR/xcode-runner.sh"

# Local runs: fail fast on post-suite diagnostics hang (45s default is for CI).
# Keep CI at 45s for full log flush; cut local to 10s so agents get feedback quickly.
if [[ "${GITHUB_ACTIONS:-}" != "true" && -z "${TRINKET_XCODE_IDLE_TIMEOUT_SECONDS:-}" ]]; then
  export TRINKET_XCODE_IDLE_TIMEOUT_SECONDS=10
fi

# Parse arguments
MODE="unit"
NO_BUILD=false
QUIET=true
VERBOSE=false
APP_ONLY=false
TARGETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    ui|--ui)
      MODE="ui"
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
    performance|--performance)
      MODE="performance"
      shift
      ;;
    no-build|--no-build)
      NO_BUILD=true
      shift
      ;;
    --app-only|app-only)
      # Path-scoped app compile coverage (packages are scheduled separately).
      APP_ONLY=true
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
      if [[ "$1" == -* ]]; then
        echo "Unknown option: $1" >&2
        echo "Usage: $0 [unit | ui | style | smoke | performance] [--no-build] [--app-only] [TestClass[/testMethod]|SwiftPath ...]" >&2
      echo "       bare 'ui' (full suite) locally requires TRINKET_ALLOW_FULL_UI=1; CI and targeted runs do not." >&2
        exit 1
      fi
      TARGETS+=("$1")
      shift
      ;;
  esac
done

if [[ "$MODE" == "style" ]]; then
  # shellcheck source=lib/test-style.sh
  source "$SCRIPT_DIR/lib/test-style.sh"
  style_paths=()
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    style_paths=("${TARGETS[@]}")
  fi
  if (( ${#style_paths[@]} > 0 )); then
    if ! trinket_run_style_gate "${style_paths[@]}"; then
      exit $?
    fi
  else
    if ! trinket_run_style_gate; then
      exit $?
    fi
  fi
  exit 0
fi

if [[ "$APP_ONLY" == true && "$MODE" != "unit" ]]; then
  echo "--app-only is only supported with unit mode." >&2
  exit 1
fi

# Full exhaustive UI is CI-owned (sharded post-push on main). Bare local runs
# need an explicit opt-in so routine development never pays for that suite;
# single-target debugging stays unrestricted.
if [[ "$MODE" == "ui" && ${#TARGETS[@]} -eq 0 \
  && "${GITHUB_ACTIONS:-}" != "true" && "${TRINKET_ALLOW_FULL_UI:-}" != "1" ]]; then
  echo "Refusing a bare local full exhaustive UI run: CI owns that suite post-push." >&2
  echo "Debug one feature shard: ./Scripts/test.sh ui <TestClass>" >&2
  echo "Deliberate full run (release-time deploy verification): TRINKET_ALLOW_FULL_UI=1 $0 ui" >&2
  exit 1
fi

# Bare `unit` mode runs the package schemes only. There is no app-level unit
# bundle (the TrinketTests target was removed), so the app path exists only for
# --app-only (path-scoped app build).
RUN_PACKAGES_ONLY=false
if [[ "$MODE" == "unit" && ${#TARGETS[@]} -eq 0 && "$APP_ONLY" == false ]]; then
  RUN_PACKAGES_ONLY=true
fi

if [[ "$APP_ONLY" == true ]]; then
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    echo "--app-only does not accept test filters; it is a compile-only app build." >&2
    exit 1
  fi
  echo "App-only unit mode: building the app for compile coverage."
  exec ./Scripts/build.sh
fi

append_ui_target_filters() {
  local target
  for target in "${TARGETS[@]}"; do
    if [[ "$target" == TrinketUITests* ]]; then
      TEST_TARGET_FLAG+=("-only-testing:$target")
    else
      TEST_TARGET_FLAG+=("-only-testing:TrinketUITests/$target")
    fi
  done
}

mkdir -p "$RESULTS_DIR"
if [[ "$NO_BUILD" == "false" ]]; then
  prepare_generated_inputs "$RESULTS_DIR"
fi

# shellcheck source=ensure-simulator.sh
source "$SCRIPT_DIR/ensure-simulator.sh"
trinket_sim_slot_ensure
# Shared human runs lease Trinket Run so concurrent non-isolated runs fail fast
# instead of fighting over boot/erase state and DerivedData.
if [[ "${TRINKET_ISOLATE:-}" != "1" ]]; then
  trinket_shared_sim_lease_acquire
fi

# shellcheck source=lib/xcodebuild-infra.sh
source "$SCRIPT_DIR/lib/xcodebuild-infra.sh"

# Determine xcodebuild test target constraints using arrays to prevent zsh argument splitting issues
TEST_TARGET_FLAG=()
PARALLEL_FLAGS=()

# UI/smoke/performance tiers run serially against the managed test simulator.
prepare_serial_test_sim() {
  ensure_test_simulator_logged
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
}

case "$MODE" in
  smoke|performance|ui)
    trinket_ui_slot_acquire
    ;;
esac
if [[ "$MODE" == "unit" ]]; then
  if [[ "$RUN_PACKAGES_ONLY" == "true" ]]; then
    # Bare unit mode runs package schemes only; no app test plan is executed.
    : # TEST_TARGET_FLAG stays empty
  else
    echo "Targeted app-level unit runs are not supported (the TrinketTests target was removed)." >&2
    echo "Run package-scoped tests with ./Scripts/test-package.sh <Package>." >&2
    exit 1
  fi
  prepare_serial_test_sim
elif [[ "$MODE" == "smoke" ]]; then
  # Local and CI smoke share Smoke.xctestplan (shell + battle + shop).
  TEST_TARGET_FLAG=(-testPlan Smoke)
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    echo "Running targeted UI smoke tests via Smoke test plan..."
    append_ui_target_filters
  else
    echo "Running UI smoke suite via Smoke test plan..."
  fi
  prepare_serial_test_sim
elif [[ "$MODE" == "performance" ]]; then
  TEST_TARGET_FLAG=(-testPlan BattlePerformance)
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    append_ui_target_filters
  fi
  # Xcode only forwards TEST_RUNNER_* into the XCTest process (prefix stripped).
  if [[ -n "${TRINKET_PERFORMANCE_QUICK:-}" ]]; then
    export TEST_RUNNER_TRINKET_PERFORMANCE_QUICK="$TRINKET_PERFORMANCE_QUICK"
  fi
  if [[ -n "${TRINKET_PERFORMANCE_REPETITIONS:-}" ]]; then
    export TEST_RUNNER_TRINKET_PERFORMANCE_REPETITIONS="$TRINKET_PERFORMANCE_REPETITIONS"
  fi
  if [[ "${TRINKET_PERFORMANCE_QUICK:-}" == "1" ]]; then
    echo "Running the dedicated app performance scenario matrix (quick measure window)..."
  else
    echo "Running the dedicated app performance scenario matrix..."
  fi
  prepare_serial_test_sim
elif [[ "$MODE" == "ui" ]]; then
  TEST_TARGET_FLAG=(-testPlan FullUI)
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    echo "Running targeted UI tests..."
    append_ui_target_filters
  else
    echo "Running only UI tests (TrinketUITests)..."
    TEST_TARGET_FLAG=(-testPlan FullUI -only-testing:TrinketUITests)
  fi
  prepare_serial_test_sim
fi

trinket_run_env_install_self_clean

mkdir -p "$RESULTS_DIR"
ACTION="test"
RUN_FINGERPRINT="$MODE"
if [[ ${#TARGETS[@]} -gt 0 ]]; then
  for target in "${TARGETS[@]}"; do
    RUN_FINGERPRINT+="_$target"
  done
fi
BUILD_STAMP="$(build_stamp_path "$RESULTS_DIR" "$RUN_FINGERPRINT")"
if [[ ! -f "$BUILD_STAMP" && "$RUN_FINGERPRINT" != "$MODE" ]]; then
  # A targeted run reuses the prior mode-level build when its exact fingerprint
  # was not stamped (e.g. adding a new smoke/UI class must not break --no-build).
  BUILD_STAMP="$(build_stamp_path "$RESULTS_DIR" "$MODE")"
fi
# Automatic build reuse for agents: if inputs are unchanged since the last
# matching build, run without rebuilding even without an explicit --no-build.
# This makes the fast path the default; dirty inputs still trigger a rebuild.
if [[ "$NO_BUILD" == "false" && "$RUN_PACKAGES_ONLY" == "false" ]]; then
  if [[ -f "$BUILD_STAMP" ]]; then
    if assert_no_build_inputs_are_fresh "$BUILD_STAMP" "$RUN_FINGERPRINT" >/dev/null 2>&1; then
      built_app="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Trinket.app"
      if [[ -d "$built_app" ]]; then
        echo "Build reuse: inputs unchanged since last '$RUN_FINGERPRINT' — running tests without rebuilding."
        echo "  (No action needed: rebuilds happen automatically when inputs change.)"
        NO_BUILD=true
      fi
    fi
  fi
fi
xcode_runner_prepare "$MODE" "$RESULTS_DIR"
RESULT_BUNDLE_PATH="$XCODE_RUNNER_RESULT_BUNDLE_PATH"
XCODEBUILD_LOG_PATH="$XCODE_RUNNER_LOG_PATH"
XCODEBUILD_REPORT_PREFIX="$XCODE_RUNNER_REPORT_PREFIX"

# shellcheck source=lib/test-helpers.sh
source "$SCRIPT_DIR/lib/test-helpers.sh"

record_timing() { trinket_record_timing "$@"; }
assert_no_build_is_fresh() { trinket_assert_no_build_is_fresh "$@"; }
assert_targeted_tests_executed() { trinket_assert_targeted_tests_executed "$@"; }

if [[ "$NO_BUILD" == "true" ]]; then
  if [[ "$RUN_PACKAGES_ONLY" == "true" ]]; then
    # Package stamp freshness is validated inside test-package.sh --no-build.
    :
  elif assert_no_build_is_fresh; then
    :
  else
    no_build_status=$?
    # The binary freshness guard is a wrapper/preflight failure, but it still
    # needs a completion record so CI does not classify a partial run as pass.
    xcode_runner_write_manifest "$RESULT_BUNDLE_PATH" "$XCODEBUILD_REPORT_PREFIX" "$no_build_status" "$MODE"
    exit "$no_build_status"
  fi
  ACTION="test-without-building"
fi

run_package_tests() { trinket_run_package_tests "$@"; }

TEST_WALL_SECONDS=0
SECONDS=0

if [[ "$RUN_PACKAGES_ONLY" == "true" ]]; then
  echo "Running package schemes only (no app-level unit test bundle)."
else
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
  if [[ "$MODE" == "performance" ]]; then
    # Keep DEBUG-only deterministic instrumentation while compiling the measured
    # app and test bundles with release-style Swift optimization.
    XCODEBUILD_ARGS+=(SWIFT_OPTIMIZATION_LEVEL=-O)
  fi
  if [[ ${#TEST_TARGET_FLAG[@]} -gt 0 ]]; then
    XCODEBUILD_ARGS+=("${TEST_TARGET_FLAG[@]}")
  fi
  if [[ ${#PARALLEL_FLAGS[@]} -gt 0 ]]; then
    XCODEBUILD_ARGS+=("${PARALLEL_FLAGS[@]}")
  fi

  runner_args=(
    --label "$MODE"
    --result-bundle "$RESULT_BUNDLE_PATH"
    --log "$XCODEBUILD_LOG_PATH"
    --report-prefix "$XCODEBUILD_REPORT_PREFIX"
    --retry-callback trinket_xcodebuild_log_is_infrastructure_failure
  )
  if [[ "$QUIET" == "true" ]]; then
    runner_args+=(--quiet)
  else
    runner_args+=(--verbose)
  fi
  xcode_runner_run "${runner_args[@]}" -- xcodebuild "${XCODEBUILD_ARGS[@]}" || XCODEBUILD_EXIT_CODE=$?

  TEST_WALL_SECONDS=$SECONDS

  if [[ "$XCODEBUILD_EXIT_CODE" -eq 0 ]]; then
    if ! assert_targeted_tests_executed; then
      xcode_runner_write_manifest "$RESULT_BUNDLE_PATH" "$XCODEBUILD_REPORT_PREFIX" 1 "$MODE"
      exit 1
    fi
    echo "Tests succeeded!"
  fi

  if [[ "$XCODEBUILD_EXIT_CODE" -ne 0 ]]; then
    record_timing
    echo ""
    echo "Timing recorded. Hotspots: ./Scripts/test-timing.sh"
    exit "$XCODEBUILD_EXIT_CODE"
  fi
fi

if [[ "$RUN_PACKAGES_ONLY" == "true" ]]; then
  echo "Running package tests..."
  # Mirror the app path: record wall timing before exiting on failure so a
  # failed package run still contributes a sample to the timing history.
  if ! run_package_tests "$ACTION"; then
    record_timing
    exit 1
  fi
fi

if [[ "$NO_BUILD" == "false" && "$RUN_PACKAGES_ONLY" == "false" ]]; then
  touch_build_stamp "$RESULTS_DIR" "$RUN_FINGERPRINT"
  # A targeted run also stamps its mode so later targeted --no-build runs can
  # fall back to the mode-level stamp (see BUILD_STAMP fallback above).
  if [[ "$RUN_FINGERPRINT" != "$MODE" ]]; then
    touch_build_stamp "$RESULTS_DIR" "$MODE"
  fi
fi

record_timing
echo ""
echo "Timing recorded. Hotspots: ./Scripts/test-timing.sh"
