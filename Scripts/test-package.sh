#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA_PATH="$PWD/.DerivedData"
RESULTS_DIR="$DERIVED_DATA_PATH/TestResults"
SCRIPT_DIR="$(dirname "$0")"

ACTION="test"
DESTINATION=""
PACKAGES=()

usage() {
  cat <<'USAGE'
Usage: ./Scripts/test-package.sh [--no-build] [--destination DESTINATION] <Package> [Package...]

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
    TrinketCore|TrinketContent|TrinketPersistence|TrinketDesignSystem)
      echo "$1"
      ;;
    BattleEngine)
      echo "BattleEngine-Package"
      ;;
    *)
      echo "Unknown package '$1'." >&2
      usage >&2
      return 1
      ;;
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

  echo "Running $package package tests..."
  rm -rf "$result_bundle"

  package_status=0
  (
    cd "Packages/$package"
    xcodebuild "$ACTION" \
      -scheme "$scheme" \
      -sdk iphonesimulator \
      -destination "$DESTINATION" \
      -derivedDataPath "$DERIVED_DATA_PATH/${package}Package" \
      -resultBundlePath "$result_bundle"
  ) || package_status=$?

  if xcresult_failed "$result_bundle"; then
    package_status=1
  fi

  if [[ "$package_status" -ne 0 ]]; then
    exit "$package_status"
  fi
done
