#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
SCRIPT_DIR="$(dirname "$0")"

# Must match Scripts/build-for-testing.sh so CI --no-build restores the same products.
# shellcheck source=run-env.sh
source "$SCRIPT_DIR/run-env.sh"
trinket_run_env_init

# shellcheck source=build-stamp.sh
source "$SCRIPT_DIR/build-stamp.sh"
# shellcheck source=build-inputs.sh
source "$SCRIPT_DIR/build-inputs.sh"
# shellcheck source=xcode-runner.sh
source "$SCRIPT_DIR/xcode-runner.sh"

ACTION="test"
DESTINATION=""
PACKAGES=()
QUIET=true
VERBOSE=false
DEFER_TERMINAL_OUTPUT=false
REPORT_PREFIX=""
INCLUDE_BALANCE_SWEEP_TESTS=false
DID_ENSURE_SIMULATOR=false

usage() {
  cat <<'USAGE'
Usage: ./Scripts/test-package.sh [--no-build] [--build-only] [--destination DESTINATION] [--verbose] [--quiet] [--include-balance-sweep-tests] <Package> [Package...]

Runs Swift package test schemes from inside their package directories, allocating
a unique result bundle for each invocation so repeated runs do not collide.

When multiple packages are passed, builds/tests run in parallel using per-package
DerivedData tenants (same model as `test.sh unit`), with SYMROOT/OBJROOT pinned
into each tenant so SPM schemes do not share Packages/.DerivedData/build.db.

--build-only compiles the package scheme without running tests (local verify
presentation-only demotion). BattleEngine balance-sweep tests are skipped by
default; pass --include-balance-sweep-tests for a one-off balance-tool test run.

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
    --build-only|build-only)
      ACTION="build"
      shift
      ;;
    --destination)
      if [[ $# -lt 2 ]]; then
        echo "--destination requires a value." >&2
        usage >&2
        exit 1
      fi
      DESTINATION="$2"
      shift 2
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
    --help|-h)
      usage
      exit 0
      ;;
    *)
      PACKAGES+=("$1")
      shift
      ;;
  esac
done

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  usage >&2
  exit 1
fi

# shellcheck source=ensure-simulator.sh
source "$SCRIPT_DIR/ensure-simulator.sh"
trinket_sim_slot_ensure

if [[ -z "$DESTINATION" ]]; then
  ensure_test_simulator_logged
  DESTINATION="$SIMULATOR_DESTINATION"
  DID_ENSURE_SIMULATOR=true
fi
if [[ "$DID_ENSURE_SIMULATOR" == "true" ]]; then
  trinket_run_env_install_test_simulator_cleanup
fi

mkdir -p "$RESULTS_DIR"
if [[ "$ACTION" == "test" ]]; then
  prepare_generated_inputs "$RESULTS_DIR"
fi

run_one_package() {
  local package="$1"
  local defer_output="${2:-false}"
  local scheme
  local package_report_prefix=""
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
  result_bundle="$XCODE_RUNNER_RESULT_BUNDLE_PATH"
  log_file="$XCODE_RUNNER_LOG_PATH"
  package_report_prefix="$XCODE_RUNNER_REPORT_PREFIX"
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
    if [[ "$ACTION" == "build" ]]; then
      echo "Building $package package (build-only)..."
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
  xcodebuild_args=(
    xcodebuild "$ACTION" \
      -scheme "$scheme" \
      -sdk iphonesimulator \
      -destination "$DESTINATION" \
      -derivedDataPath "$package_dd" \
      -resultBundlePath "$result_bundle" \
      "SYMROOT=$(package_symroot "$package_dd")" \
      "OBJROOT=$(package_objroot "$package_dd")" \
      "SHARED_PRECOMPS_DIR=$(package_shared_precomps_dir "$package_dd")"
  )
  # Test filters only apply to test / test-without-building.
  if [[ "$ACTION" != "build" && ${#package_test_filters[@]} -gt 0 ]]; then
    xcodebuild_args+=("${package_test_filters[@]}")
  fi
  xcode_runner_run "${runner_args[@]}" -- "${xcodebuild_args[@]}" || package_status=$?

  if [[ "$package_status" -ne 0 ]]; then
    return "$package_status"
  fi

  if [[ "$ACTION" == "test" || "$ACTION" == "build" ]]; then
    touch_build_stamp "$RESULTS_DIR" "package_$package"
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

package_run_token="$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM:-0}"
package_output_root="$RESULTS_DIR/.deferred/test-package-$package_run_token"
mkdir -p "$package_output_root"

if [[ "$ACTION" == "build" ]]; then
  echo "Building ${#PACKAGES[@]} packages in parallel (jobs=$jobs)..."
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

  export DERIVED_DATA_PATH="$derived_data_path"
  export RESULTS_DIR="$results_dir"
  # Children already share a prepared generate stamp / SKIP_GENERATE from parents.
  export SKIP_GENERATE=1

  package_args=("$package" --destination "$destination" --defer-terminal-output)
  case "$action" in
    test-without-building) package_args=(--no-build "${package_args[@]}") ;;
    build) package_args=(--build-only "${package_args[@]}") ;;
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

  status=0
  ./Scripts/test-package.sh "${package_args[@]}" >"$output_root/$package.stdout" 2>&1 || status=$?
  printf "%s\n" "$status" >"$output_root/$package.status"
  exit "$status"
' _ {} "$DESTINATION" "$ACTION" "$QUIET" "$VERBOSE" "$REPORT_PREFIX" "$INCLUDE_BALANCE_SWEEP_TESTS" "$package_output_root" "$DERIVED_DATA_PATH" "$RESULTS_DIR" || failed=1

# Emit deferred output in declaration order after all workers finish.
for package in "${PACKAGES[@]}"; do
  status_file="$package_output_root/$package.status"
  stdout_file="$package_output_root/$package.stdout"
  package_status=1
  if [[ -f "$status_file" ]]; then
    package_status="$(cat "$status_file")"
  fi
  if [[ -s "$stdout_file" ]]; then
    cat "$stdout_file"
  elif [[ "$package_status" -eq 0 ]]; then
    echo "Package $package completed without deferred output."
  else
    echo "Package $package failed without deferred output." >&2
  fi
  if [[ "$package_status" != "0" ]]; then
    failed=1
  fi
done

exit "$failed"
