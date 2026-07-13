#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# Must match Scripts/build-for-testing.sh so CI --no-build restores the same products.
DERIVED_DATA_PATH="$PWD/.DerivedData"
RESULTS_DIR="$DERIVED_DATA_PATH/TestResults"
SCRIPT_DIR="$(dirname "$0")"

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

usage() {
  cat <<'USAGE'
Usage: ./Scripts/test-package.sh [--no-build] [--destination DESTINATION] [--verbose] [--quiet] <Package> [Package...]

Runs Swift package test schemes from inside their package directories, allocating
a unique result bundle for each invocation so repeated runs do not collide.

Packages:
  TrinketCore
  TrinketContent
  BattleEngine
  TrinketPersistence
  TrinketDesignSystem
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    no-build|--no-build)
      ACTION="test-without-building"
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

if [[ -z "$DESTINATION" ]]; then
  ensure_test_simulator_logged
  DESTINATION="$SIMULATOR_DESTINATION"
fi

mkdir -p "$RESULTS_DIR"

for package in "${PACKAGES[@]}"; do
  scheme="$(package_test_scheme "$package")"
  package_report_prefix=""
  if [[ -n "$REPORT_PREFIX" ]]; then
    package_report_prefix="${REPORT_PREFIX}-${package}"
  fi
  xcode_runner_prepare "$package" "$RESULTS_DIR" "$package_report_prefix"
  result_bundle="$XCODE_RUNNER_RESULT_BUNDLE_PATH"
  log_file="$XCODE_RUNNER_LOG_PATH"
  package_report_prefix="$XCODE_RUNNER_REPORT_PREFIX"

  if [[ "$ACTION" == "test-without-building" ]]; then
    if assert_no_build_inputs_are_fresh \
      "$(build_stamp_path "$RESULTS_DIR" "package_$package")" \
      "package_$package"; then
      :
    else
      freshness_status=$?
      # This is a wrapper/preflight failure rather than an Xcode invocation;
      # still leave a completion record so CI cannot mistake a partial unit
      # run for a clean pass.
      xcode_runner_write_manifest "$result_bundle" "$package_report_prefix" "$freshness_status" "$package"
      exit "$freshness_status"
    fi
  fi

  package_status=0
  if [[ "$DEFER_TERMINAL_OUTPUT" == "false" ]]; then
    echo "Running $package package tests..."
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
  if [[ "$DEFER_TERMINAL_OUTPUT" == "true" ]]; then
    runner_args+=(--defer-terminal-output)
  fi
  xcode_runner_run "${runner_args[@]}" -- \
    xcodebuild "$ACTION" \
      -scheme "$scheme" \
      -sdk iphonesimulator \
      -destination "$DESTINATION" \
      -derivedDataPath "$DERIVED_DATA_PATH" \
      -resultBundlePath "$result_bundle" \
    || package_status=$?

  if [[ "$package_status" -ne 0 ]]; then
    exit "$package_status"
  fi

  if [[ "$ACTION" == "test" ]]; then
    touch_build_stamp "$RESULTS_DIR" "package_$package"
  fi
done
