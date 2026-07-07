#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA_PATH="$PWD/.DerivedData"
RESULTS_DIR="$DERIVED_DATA_PATH/TestResults"
SCRIPT_DIR="$(dirname "$0")"

ACTION="test"
DESTINATION=""
PACKAGES=()
QUIET=true
VERBOSE=false

usage() {
  cat <<'USAGE'
Usage: ./Scripts/test-package.sh [--no-build] [--destination DESTINATION] [--verbose] [--quiet] <Package> [Package...]

Runs Swift package test schemes from inside their package directories, removing
the package result bundle first so repeated runs do not fail on stale xcresults.

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
  ensure_test_simulator
  DESTINATION="$SIMULATOR_DESTINATION"
fi

mkdir -p "$RESULTS_DIR"

scheme_for_package() {
  case "$1" in
    BattleEngine) echo "BattleEngine-Package" ;;
    *) echo "$1" ;;
  esac
}

xcresult_failed() {
  local result_path="$1"
  [[ -d "$result_path" ]] || return 1
  xcrun xcresulttool get test-results summary --path "$result_path" 2>/dev/null \
    | grep -Eq '"result" : "(Failed|unknown)"'
}

for package in "${PACKAGES[@]}"; do
  scheme="$(scheme_for_package "$package")"
  result_bundle="$RESULTS_DIR/${package}.xcresult"
  log_file="$RESULTS_DIR/${package}-xcodebuild.log"

  rm -rf "$result_bundle"

  package_status=0
  if [[ "$QUIET" == "true" ]]; then
    echo "Running $package package tests... (raw log at .DerivedData/TestResults/${package}-xcodebuild.log)"
    (
      cd "Packages/$package"
      xcodebuild "$ACTION" \
        -scheme "$scheme" \
        -sdk iphonesimulator \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -resultBundlePath "$result_bundle"
    ) > "$log_file" 2>&1 || package_status=$?
  elif command -v xcbeautify &>/dev/null; then
    echo "Running $package package tests..."
    (
      cd "Packages/$package"
      xcodebuild "$ACTION" \
        -scheme "$scheme" \
        -sdk iphonesimulator \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -resultBundlePath "$result_bundle"
    ) | xcbeautify || package_status=${PIPESTATUS[0]}
  else
    echo "Running $package package tests..."
    (
      cd "Packages/$package"
      xcodebuild "$ACTION" \
        -scheme "$scheme" \
        -sdk iphonesimulator \
        -destination "$DESTINATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        -resultBundlePath "$result_bundle"
    ) || package_status=$?
  fi

  if xcresult_failed "$result_bundle"; then
    package_status=1
  fi

  if [[ "$package_status" -ne 0 ]]; then
    ./Scripts/summarize-failures.py "$result_bundle"
    if [[ "$QUIET" == "true" && ! -d "$result_bundle" ]]; then
      echo -e "\n\033[1;31m=== $package BUILD FAILURE ===\033[0m"
      grep -E -A 2 -i "error:|warning:|failed:" "$log_file" | head -n 40 || tail -n 40 "$log_file"
    fi
    exit "$package_status"
  fi
done
