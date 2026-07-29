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
    performance|--performance)
      MODE="performance"
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
      if [[ "$1" == -* ]]; then
        echo "Unknown option: $1" >&2
        echo "Usage: $0 [unit | ui | all | style | smoke | smoke-full | performance] [--no-build] [TestClass[/testMethod] ...]" >&2
        exit 1
      fi
      TARGETS+=("$1")
      shift
      ;;
  esac
done

if [[ "$MODE" == "style" ]]; then
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    echo "Target filters are not supported for style mode."
    echo "Usage: $0 [unit | ui | all | style | smoke | smoke-full | performance] [--no-build] [TestClass[/testMethod] ...]"
    exit 1
  fi

  # Fail closed: every style subgate must succeed. Do not `exit 0` after a soft failure.
  style_status=0
  ./Scripts/format.sh --lint || style_status=$?
  ./Scripts/lint.sh || style_status=$?
  ./Scripts/check-ui-style.sh || style_status=$?
  ./Scripts/check-platform-api-bans.sh || style_status=$?
  ./Scripts/check-exclusivity-footguns.sh || style_status=$?
  if [[ "$style_status" -ne 0 ]]; then
    echo "Style gate failed (format / lint / UI style / platform API bans / exclusivity)." >&2
    exit "$style_status"
  fi
  echo "Style gate passed."
  exit 0
fi

mkdir -p "$RESULTS_DIR"
if [[ "$NO_BUILD" == "false" ]]; then
  prepare_generated_inputs "$RESULTS_DIR"
fi

# shellcheck source=ensure-simulator.sh
source "$SCRIPT_DIR/ensure-simulator.sh"
trinket_sim_slot_ensure

# shellcheck source=lib/xcodebuild-infra.sh
source "$SCRIPT_DIR/lib/xcodebuild-infra.sh"

retryable_xcodebuild_infrastructure_failure() {
  local exit_code="$1"
  local log_file="$2"
  trinket_xcodebuild_log_is_infrastructure_failure "$exit_code" "$log_file"
}

# Determine xcodebuild test target constraints using arrays to prevent zsh argument splitting issues
TEST_TARGET_FLAG=()
PARALLEL_FLAGS=()
case "$MODE" in
  smoke|smoke-full|performance|ui|all)
    trinket_ui_slot_acquire
    ;;
esac
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
    echo "Usage: $0 [unit | ui | all | style | smoke | smoke-full | performance] [--no-build] [TestClass[/testMethod] ...]"
    exit 1
  fi
  TEST_TARGET_FLAG=(-testPlan Smoke)
  echo "Running full UI smoke suite via Smoke test plan..."
  ensure_test_simulator_logged
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
elif [[ "$MODE" == "performance" ]]; then
  TEST_TARGET_FLAG=(-testPlan BattlePerformance)
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    for target in "${TARGETS[@]}"; do
      if [[ "$target" == TrinketUITests* ]]; then
        TEST_TARGET_FLAG+=("-only-testing:$target")
      else
        TEST_TARGET_FLAG+=("-only-testing:TrinketUITests/$target")
      fi
    done
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
    echo "Usage: $0 [unit | ui | all | style | smoke | smoke-full | performance] [--no-build] [TestClass[/testMethod] ...]"
    exit 1
  fi
  echo "Running all tests via Xcode Test Plan..."
  TEST_TARGET_FLAG=(-testPlan Integration)
  ensure_test_simulator_logged
  PARALLEL_FLAGS=(-parallel-testing-enabled NO)
fi

mkdir -p "$RESULTS_DIR"
ACTION="test"
RUN_FINGERPRINT="$MODE"
if [[ ${#TARGETS[@]} -gt 0 ]]; then
  for target in "${TARGETS[@]}"; do
    RUN_FINGERPRINT+="_$target"
  done
fi
BUILD_STAMP="$(build_stamp_path "$RESULTS_DIR" "$RUN_FINGERPRINT")"
xcode_runner_prepare "$MODE" "$RESULTS_DIR"
RESULT_BUNDLE_PATH="$XCODE_RUNNER_RESULT_BUNDLE_PATH"
XCODEBUILD_LOG_PATH="$XCODE_RUNNER_LOG_PATH"
XCODEBUILD_REPORT_PREFIX="$XCODE_RUNNER_REPORT_PREFIX"

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
    return 1
  fi

  assert_no_build_inputs_are_fresh "$BUILD_STAMP" "$RUN_FINGERPRINT"
}

assert_targeted_tests_executed() {
  [[ ${#TARGETS[@]} -gt 0 ]] || return 0
  [[ -d "$RESULT_BUNDLE_PATH" ]] || return 0
  command -v xcrun >/dev/null 2>&1 || return 0

  local summary_json
  summary_json="$(xcrun xcresulttool get test-results summary --path "$RESULT_BUNDLE_PATH" --compact 2>/dev/null || true)"
  [[ -n "$summary_json" ]] || return 0
  if ! python3 - "$summary_json" <<'PY'
import json
import sys

def number(value):
    if isinstance(value, dict) and "_value" in value:
        value = value["_value"]
    if isinstance(value, bool):
        return 0
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0

try:
    payload = json.loads(sys.argv[1])
except json.JSONDecodeError:
    raise SystemExit(0)

total = sum(number(payload.get(key)) for key in ("passedTests", "failedTests", "skippedTests"))
if total == 0:
    total = number(payload.get("totalTests"))
raise SystemExit(0 if total > 0 else 1)
PY
  then
    echo "Targeted test filter executed zero tests; refusing a false-green result." >&2
    return 1
  fi
}

if [[ "$NO_BUILD" == "true" ]]; then
  if assert_no_build_is_fresh; then
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

run_package_tests() {
  local xcodebuild_action="$1"
  local packages=("${TRINKET_TEST_PACKAGES[@]}")
  local failed=0
  local build_seconds=0
  local test_seconds=0
  local package
  local package_status
  local jobs
  local cpu_count

  # Package schemes use per-package DerivedData tenants so builds can run in
  # parallel without contending on a shared build.db.
  if [[ "$xcodebuild_action" != "test-without-building" ]]; then
    SECONDS=0
    package_build_token="$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM:-0}"
    package_build_output="$RESULTS_DIR/.deferred/package-build-$package_build_token"
    mkdir -p "$package_build_output"
    cpu_count="$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"
    build_jobs="$cpu_count"
    if [[ "$build_jobs" -gt ${#packages[@]} ]]; then
      build_jobs=${#packages[@]}
    fi
    if [[ "$build_jobs" -lt 1 ]]; then
      build_jobs=1
    fi
    echo "Building package tests in parallel (jobs=$build_jobs)..."
    printf '%s\n' "${packages[@]}" | xargs -P "$build_jobs" -I{} bash -c '
      set -euo pipefail
      package="$1"
      results_dir="$2"
      derived_data_path="$3"
      destination="$4"
      output_root="$5"
      script_dir="$6"
      repo_root="$7"

      export DERIVED_DATA_PATH="$derived_data_path"
      # shellcheck source=build-stamp.sh
      source "$script_dir/build-stamp.sh"
      # shellcheck source=xcode-runner.sh
      source "$script_dir/xcode-runner.sh"

      package_dd="$(package_derived_data_path "$package")"
      mkdir -p "$package_dd"

      echo "Building $package package tests..."
      package_status=0
      xcode_runner_prepare "package-build-$package" "$results_dir"
      package_build_result="$XCODE_RUNNER_RESULT_BUNDLE_PATH"
      package_build_log="$XCODE_RUNNER_LOG_PATH"
      package_build_report="$XCODE_RUNNER_REPORT_PREFIX"
      build_runner_args=(
        --label "package-build-$package"
        --result-bundle "$package_build_result"
        --log "$package_build_log"
        --report-prefix "$package_build_report"
        --quiet
        --working-directory "$repo_root/Packages/$package"
      )
      xcode_runner_run "${build_runner_args[@]}" -- \
        xcodebuild build-for-testing \
          -scheme "$(package_test_scheme "$package")" \
          -sdk iphonesimulator \
          -destination "$destination" \
          -derivedDataPath "$package_dd" \
          -resultBundlePath "$package_build_result" \
        || package_status=$?
      if [[ "$package_status" -eq 0 ]]; then
        touch_build_stamp "$results_dir" "package_$package"
      fi
      printf "%s\n" "$package_status" >"$output_root/$package.status"
      exit "$package_status"
    ' _ {} "$RESULTS_DIR" "$DERIVED_DATA_PATH" "$SIMULATOR_DESTINATION" "$package_build_output" "$SCRIPT_DIR" "$PWD" || failed=1

    for package in "${packages[@]}"; do
      status_file="$package_build_output/$package.status"
      if [[ ! -f "$status_file" ]] || [[ "$(cat "$status_file")" != "0" ]]; then
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
  package_run_token="$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM:-0}"
  package_report_root="$RESULTS_DIR/unit-packages-$package_run_token"
  package_output_root="$RESULTS_DIR/.deferred/$package_run_token"
  mkdir -p "$package_output_root"
  SECONDS=0
  printf '%s\n' "${packages[@]}" | xargs -P "$jobs" -I{} bash -c '
    set -euo pipefail
    package="$1"
    destination="$2"
    quiet="$3"
    verbose="$4"
    report_root="$5"
    output_root="$6"
    package_args=(--no-build "$package" --destination "$destination" --defer-terminal-output --report-prefix "$report_root")
    if [[ "$quiet" == "true" ]]; then
      package_args+=(--quiet)
    fi
    if [[ "$verbose" == "true" ]]; then
      package_args+=(--verbose)
    fi
    ./Scripts/test-package.sh "${package_args[@]}" >"$output_root/$package.stdout" 2>&1
  ' _ {} "$SIMULATOR_DESTINATION" "$QUIET" "$VERBOSE" "$package_report_root" "$package_output_root" || failed=1
  test_seconds=$SECONDS

  # Child output is intentionally deferred while packages run in parallel.
  # Emit one deterministic aggregate section in package declaration order.
  for package in "${packages[@]}"; do
    package_report="${package_report_root}-${package}"
    package_manifest=""
    while IFS= read -r candidate; do
      package_manifest="$candidate"
    done < <(find "$RESULTS_DIR" -maxdepth 1 -type f -name "${package}-*-invocation.json" | sort)
    if [[ -f "${package_report}.md" && -n "$package_manifest" ]] \
      && grep -q '"status":"failed"' "$package_manifest"; then
      cat "${package_report}.md"
    elif [[ -s "$package_output_root/$package.stdout" ]]; then
      cat "$package_output_root/$package.stdout"
    else
      echo "Package $package completed without diagnostics."
    fi
  done

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
  --retry-callback retryable_xcodebuild_infrastructure_failure
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
  if [[ -d "$RESULT_BUNDLE_PATH" ]]; then
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
