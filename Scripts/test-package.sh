#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
SCRIPT_DIR="$(dirname "$0")"

# Must match Scripts/build-for-testing.sh so CI --no-build restores the same products.
# shellcheck source=run-env.sh
source "$SCRIPT_DIR/run-env.sh"

# shellcheck source=build-freshness.sh
source "$SCRIPT_DIR/build-freshness.sh"
# shellcheck source=xcode-runner.sh
source "$SCRIPT_DIR/xcode-runner.sh"
source "$SCRIPT_DIR/lib/app-build.sh"

ACTION="test"
DESTINATION=""
PACKAGES=()
QUIET=true
VERBOSE=false
DEFER_TERMINAL_OUTPUT=false
REPORT_PREFIX=""
INCLUDE_BALANCE_SWEEP_TESTS=false
DID_ENSURE_SIMULATOR=false
ITERATIONS=""
RUN_UNTIL_FAILURE=false

usage() {
  cat <<'USAGE'
Usage: ./Scripts/test-package.sh [--no-build] [--build-for-testing] [--destination DESTINATION] [--verbose] [--quiet] [--include-balance-sweep-tests] [--iterations COUNT] [--run-tests-until-failure] <Package> [Package...]

Runs Swift package test schemes from inside their package directories, allocating
a unique result bundle for each invocation so repeated runs do not collide.

When multiple packages are passed, builds/tests run in parallel using per-package
DerivedData tenants (same model as `test.sh unit`), with SYMROOT/OBJROOT pinned
into each tenant so SPM schemes do not share Packages/.DerivedData/build.db.

--destination accepts iOS Simulator destinations only (including name or UUID overrides).
It cannot be combined with --build-for-testing.
--build-for-testing compiles each package scheme against a generic simulator destination
and stamps package_<name> so later --no-build runs can reuse the products. BattleEngine
balance-sweep tests are skipped by default; pass --include-balance-sweep-tests for a
one-off balance-tool test run.
--iterations repeats test execution COUNT times (e.g. for reproducibility).
--run-tests-until-failure repeats tests until a failure occurs (defaults to 10 iterations when --iterations is omitted).
TRINKET_SERIAL_TESTS=1 serializes test execution (diagnosing stack-pressure
crashes); TRINKET_PACKAGE_TEST_JOBS=1 serializes across packages.

Packages:
USAGE
  printf '  %s\n' "${TRINKET_TEST_PACKAGES[@]}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    no-build|--no-build)
      ACTION="test-without-building"
      shift
      ;;
    --build-for-testing|build-for-testing)
      ACTION="build-for-testing"
      shift
      ;;
    --destination)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "--destination requires a value." >&2
        usage >&2
        exit 1
      fi
      DESTINATION="$2"
      shift 2
      ;;
    --defer-terminal-output)
      DEFER_TERMINAL_OUTPUT=true
      shift
      ;;
    --report-prefix)
      if [[ $# -lt 2 ]]; then
        echo "--report-prefix requires a value." >&2
        usage >&2
        exit 1
      fi
      REPORT_PREFIX="$2"
      shift 2
      ;;
    --include-balance-sweep-tests)
      INCLUDE_BALANCE_SWEEP_TESTS=true
      shift
      ;;
    --iterations)
      if [[ $# -lt 2 || ! "$2" =~ ^[1-9][0-9]*$ ]]; then
        echo "--iterations requires a positive integer." >&2
        usage >&2
        exit 1
      fi
      ITERATIONS="$2"
      shift 2
      ;;
    --run-tests-until-failure)
      RUN_UNTIL_FAILURE=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    -*)
      if trinket_args_quiet_verbose "$1"; then shift; continue; fi
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
    *)
      if trinket_args_quiet_verbose "$1"; then shift; continue; fi
      PACKAGES+=("$1")
      shift
      ;;
  esac
done

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  usage >&2
  exit 1
fi

validated_packages=()
for package in "${PACKAGES[@]}"; do
  valid=false
  for candidate in "${TRINKET_TEST_PACKAGES[@]}"; do
    if [[ "$candidate" == "$package" ]]; then valid=true; break; fi
  done
  if [[ "$valid" != true ]]; then
    echo "Unknown package: $package" >&2
    usage >&2
    exit 1
  fi
  for candidate in "${validated_packages[@]-}"; do
    if [[ "$candidate" == "$package" ]]; then
      echo "Duplicate package: $package" >&2
      exit 1
    fi
  done
  validated_packages+=("$package")
done

if [[ "$ACTION" == "build-for-testing" ]]; then
  if [[ -n "$ITERATIONS" || "$RUN_UNTIL_FAILURE" == "true" ]]; then
    echo "Repetition options cannot be combined with --build-for-testing." >&2
    exit 1
  fi
fi

if [[ "$RUN_UNTIL_FAILURE" == "true" && -z "$ITERATIONS" ]]; then
  ITERATIONS=10
fi

if [[ -n "$DESTINATION" ]]; then
  if [[ "$ACTION" == "build-for-testing" ]]; then
    echo "--destination cannot be combined with --build-for-testing." >&2
    exit 1
  fi
  IFS=',' read -r -a destination_fields <<< "$DESTINATION"
  for field in "${destination_fields[@]}"; do
    if [[ "$field" =~ ^[[:space:]]*(generic/)?platform[[:space:]]*=(.*)$ ]]; then
      platform="${BASH_REMATCH[2]}"
      platform="${platform#"${platform%%[![:space:]]*}"}"
      platform="${platform%"${platform##*[![:space:]]}"}"
      if [[ "$platform" != "iOS Simulator" ]]; then
        echo "--destination supports only platform=iOS Simulator; received: $platform" >&2
        exit 1
      fi
    fi
  done
fi

trinket_run_env_init

# shellcheck source=ensure-simulator.sh
source "$SCRIPT_DIR/ensure-simulator.sh"
trinket_sim_slot_ensure

# build-for-testing compiles against a generic simulator destination, so no
# concrete simulator is needed and none should be booted for it.
if [[ "$ACTION" != "build-for-testing" ]]; then
  if [[ -z "$DESTINATION" ]]; then
    if [[ "${TRINKET_ISOLATE:-}" != "1" ]]; then
      trinket_shared_sim_lease_acquire
    fi
    ensure_test_simulator_logged
    DESTINATION="$SIMULATOR_DESTINATION"
    DID_ENSURE_SIMULATOR=true
  fi
  if [[ "$DID_ENSURE_SIMULATOR" == "true" ]]; then
    trinket_run_env_install_self_clean
  fi
fi

mkdir -p "$RESULTS_DIR"
if [[ "$ACTION" != "test-without-building" ]]; then
  prepare_generated_inputs "$RESULTS_DIR"
fi

run_one_package() {
  local package="$1"
  local defer_output="${2:-false}"
  local scheme
  local package_report_prefix=""
  local invocation_id
  local result_bundle
  local log_file
  local package_dd
  local package_test_filters=()
  local package_status=0
  local runner_args=()
  local xcodebuild_args=()

  scheme="$(package_test_scheme "$package")"
  if [[ -n "$REPORT_PREFIX" ]]; then
    package_report_prefix="${REPORT_PREFIX}-${package}"
  fi
  xcode_runner_prepare "$package" "$RESULTS_DIR" "$package_report_prefix"
  invocation_id="$XCODE_RUNNER_INVOCATION_ID"
  result_bundle="$XCODE_RUNNER_RESULT_BUNDLE_PATH"
  log_file="$XCODE_RUNNER_LOG_PATH"
  package_report_prefix="$XCODE_RUNNER_REPORT_PREFIX"
  if [[ -n "${TRINKET_PACKAGE_OUTPUT_ROOT:-}" ]]; then
    printf '%s\n' "$package_report_prefix" >"$TRINKET_PACKAGE_OUTPUT_ROOT/$package.report"
  fi
  package_dd="$(package_derived_data_path "$package")"
  mkdir -p "$package_dd"

  if [[ "$package" == "BattleEngine" && "$INCLUDE_BALANCE_SWEEP_TESTS" == "false" ]]; then
    package_test_filters+=("-skip-testing:BattleBalanceToolsTests")
  fi

  if [[ "$ACTION" == "test-without-building" ]]; then
    if assert_no_build_inputs_are_fresh \
      "$(build_stamp_path "$RESULTS_DIR" "package_$package")" \
      "package_$package"; then
      :
    else
      local freshness_status=$?
      # This is a wrapper/preflight failure rather than an Xcode invocation;
      # still leave a completion record so CI cannot mistake a partial unit
      # run for a clean pass.
      xcode_runner_write_manifest "$result_bundle" "$package_report_prefix" "$freshness_status" "$package"
      return "$freshness_status"
    fi
  fi

  if [[ "$defer_output" == "false" ]]; then
    if [[ "$ACTION" == "build-for-testing" ]]; then
      echo "Building $package package (build-for-testing)..."
    else
      echo "Running $package package tests..."
    fi
  fi
  runner_args=(
    --label "$package"
    --result-bundle "$result_bundle"
    --log "$log_file"
    --report-prefix "$package_report_prefix"
    --working-directory "$PWD/Packages/$package"
  )
  if [[ "$QUIET" == "true" ]]; then
    runner_args+=(--quiet)
  else
    runner_args+=(--verbose)
  fi
  if [[ "$defer_output" == "true" || "$DEFER_TERMINAL_OUTPUT" == "true" ]]; then
    runner_args+=(--defer-terminal-output)
  fi
  if [[ "$ACTION" == "build-for-testing" ]]; then
    # Generic destination compile that --no-build test runs reuse; no result
    # bundle is produced (compiles have no test cases to record).
    trinket_set_package_scheme_args "$scheme" iphonesimulator 'generic/platform=iOS Simulator' "$package_dd"
    xcodebuild_args=(
      xcodebuild build-for-testing \
        "${TRINKET_PACKAGE_SCHEME_ARGS[@]}" \
    )
  else
    trinket_set_package_scheme_args "$scheme" iphonesimulator "$DESTINATION" "$package_dd"
    xcodebuild_args=(
      xcodebuild "$ACTION" \
        "${TRINKET_PACKAGE_SCHEME_ARGS[@]}" \
    )
    # Result bundles back test timing and failure diagnostics; build-for-testing
    # runs skip them to avoid writing bulky unused xcresults.
    if [[ "$ACTION" == "test" || "$ACTION" == "test-without-building" ]]; then
      xcodebuild_args+=(-resultBundlePath "$result_bundle")
      if [[ -n "$ITERATIONS" ]]; then
        xcodebuild_args+=(-test-iterations "$ITERATIONS")
      fi
      if [[ "$RUN_UNTIL_FAILURE" == "true" ]]; then
        xcodebuild_args+=(-run-tests-until-failure)
      fi
    fi
    # Opt-in serial execution for diagnosing stack-pressure crashes on small
    # worker-thread stacks; parallel remains the default.
    if [[ "${TRINKET_SERIAL_TESTS:-0}" == "1" ]] \
      && [[ "$ACTION" == "test" || "$ACTION" == "test-without-building" ]]; then
      xcodebuild_args+=(-parallel-testing-enabled NO)
    fi
  fi
  trinket_set_local_simulator_architecture_args iphonesimulator Debug
  xcodebuild_args+=(-configuration Debug)
  if (( ${#TRINKET_LOCAL_SIMULATOR_ARCHITECTURE_ARGS[@]} )); then
    xcodebuild_args+=("${TRINKET_LOCAL_SIMULATOR_ARCHITECTURE_ARGS[@]}")
  fi
  # Test filters only apply to test / test-without-building.
  if [[ "$ACTION" != "build-for-testing" && ${#package_test_filters[@]} -gt 0 ]]; then
    xcodebuild_args+=("${package_test_filters[@]}")
  fi
  local package_wall=0
  if [[ "$ACTION" != "test-without-building" ]]; then
    begin_build_stamps "$RESULTS_DIR" "package_$package" || return $?
  fi
  SECONDS=0
  xcode_runner_run "${runner_args[@]}" -- "${xcodebuild_args[@]}" || package_status=$?
  package_wall=$SECONDS

  # Record per-package timings for on-demand hotspot mining (test-timing.py).
  # Build-for-testing runs have no test cases; skip those xcresults. Soft-fail
  # record so a corrupt/partial bundle after a hung kill cannot mask the
  # xcodebuild status.
  if [[ "$ACTION" == "test" || "$ACTION" == "test-without-building" ]] \
    && [[ -f "$result_bundle/Info.plist" ]] \
    && [[ "${TRINKET_RECORD_TIMING:-1}" != "0" ]]; then
    if [[ "$ACTION" == "test-without-building" ]]; then
      python3 ./Scripts/test-timing.py record \
        --mode "package:$package" \
        --run "$invocation_id" \
        --wall "$package_wall" \
        --xcresult "$result_bundle" \
        --no-build \
        || echo "Warning: failed to record timing for package:$package" >&2
    else
      python3 ./Scripts/test-timing.py record \
        --mode "package:$package" \
        --run "$invocation_id" \
        --wall "$package_wall" \
        --xcresult "$result_bundle" \
        || echo "Warning: failed to record timing for package:$package" >&2
    fi
  fi

  if [[ "$package_status" -ne 0 ]]; then
    return "$package_status"
  fi

  if [[ "$ACTION" == "test" || "$ACTION" == "build-for-testing" ]]; then
    touch_build_stamp "$RESULTS_DIR" "package_$package" || return $?
  fi
  return 0
}

if [[ ${#PACKAGES[@]} -eq 1 ]]; then
  run_one_package "${PACKAGES[0]}" false
  exit $?
fi

# Multi-package: parallelize across per-package DerivedData tenants.
cpu_count="$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)"
jobs="$cpu_count"
if [[ "$jobs" -gt ${#PACKAGES[@]} ]]; then
  jobs=${#PACKAGES[@]}
fi
if [[ "$jobs" -lt 1 ]]; then
  jobs=1
fi
# Builds use generic destinations and isolated DerivedData. Tests share one
# booted simulator; concurrent xcodebuild test runs SIGKILL / empty-destination
# on GitHub-hosted runners.
if [[ "$ACTION" == "test" || "$ACTION" == "test-without-building" ]]; then
  if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
    jobs=1
  elif [[ -n "${TRINKET_PACKAGE_TEST_JOBS:-}" ]]; then
    jobs="${TRINKET_PACKAGE_TEST_JOBS}"
    [[ "$jobs" =~ ^[0-9]+$ ]] || jobs=1
    (( jobs >= 1 )) || jobs=1
    if [[ "$jobs" -gt ${#PACKAGES[@]} ]]; then jobs=${#PACKAGES[@]}; fi
  fi
fi

package_run_token="$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM:-0}"
package_output_root="$RESULTS_DIR/.deferred/test-package-$package_run_token"
mkdir -p "$package_output_root"

if [[ "$ACTION" == "build-for-testing" ]]; then
  echo "Building ${#PACKAGES[@]} package schemes for testing in parallel (jobs=$jobs)..."
else
  echo "Running ${#PACKAGES[@]} package test schemes in parallel (jobs=$jobs)..."
fi

failed=0
printf '%s\n' "${PACKAGES[@]}" | xargs -P "$jobs" -I{} bash -c '
  set -euo pipefail
  package="$1"
  destination="$2"
  action="$3"
  quiet="$4"
  verbose="$5"
  report_prefix="$6"
  include_balance="$7"
  output_root="$8"
  derived_data_path="$9"
  results_dir="${10}"
  iterations="${11}"
  run_until_failure="${12}"

  export DERIVED_DATA_PATH="$derived_data_path"
  export RESULTS_DIR="$results_dir"
  export TRINKET_PACKAGE_OUTPUT_ROOT="$output_root"
  # Children already share a prepared generate stamp / SKIP_GENERATE from parents.
  export SKIP_GENERATE=1

  package_args=("$package" --defer-terminal-output)
  if [[ -n "$destination" ]]; then
    package_args+=(--destination "$destination")
  fi
  case "$action" in
    test-without-building) package_args=(--no-build "${package_args[@]}") ;;
    build-for-testing) package_args=(--build-for-testing "${package_args[@]}") ;;
  esac
  if [[ "$quiet" == "true" ]]; then
    package_args+=(--quiet)
  fi
  if [[ "$verbose" == "true" ]]; then
    package_args+=(--verbose)
  fi
  if [[ -n "$report_prefix" ]]; then
    package_args+=(--report-prefix "$report_prefix")
  fi
  if [[ "$include_balance" == "true" ]]; then
    package_args+=(--include-balance-sweep-tests)
  fi
  if [[ -n "$iterations" ]]; then
    package_args+=(--iterations "$iterations")
  fi
  if [[ "$run_until_failure" == "true" ]]; then
    package_args+=(--run-tests-until-failure)
  fi

  status=0
  ./Scripts/test-package.sh "${package_args[@]}" >"$output_root/$package.stdout" 2>&1 || status=$?
  printf "%s\n" "$status" >"$output_root/$package.status"
  exit "$status"
' _ {} "$DESTINATION" "$ACTION" "$QUIET" "$VERBOSE" "$REPORT_PREFIX" "$INCLUDE_BALANCE_SWEEP_TESTS" "$package_output_root" "$DERIVED_DATA_PATH" "$RESULTS_DIR" "$ITERATIONS" "$RUN_UNTIL_FAILURE" || failed=1

# One bounded report for the invocation; verbose mode retains complete worker output.
summary_args=("$package_output_root" "${PACKAGES[@]}")
if [[ "$VERBOSE" == "true" ]]; then summary_args=(--verbose "${summary_args[@]}"); fi
python3 Scripts/package-diagnostics.py "${summary_args[@]}" || failed=1

exit "$failed"
