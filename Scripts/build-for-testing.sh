#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA_PATH="$PWD/.DerivedData"
RESULTS_DIR="$DERIVED_DATA_PATH/TestResults"
SCRIPT_DIR="$(dirname "$0")"

source "$SCRIPT_DIR/build-stamp.sh"

mkdir -p "$RESULTS_DIR"

echo "=== build-for-testing: Trinket app and test bundles ==="
xcodebuild build-for-testing \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_PATH"

scheme_for_package() {
  case "$1" in
    BattleEngine) echo "BattleEngine-Package" ;;
    *) echo "$1" ;;
  esac
}

PACKAGES=(TrinketCore TrinketContent BattleEngine TrinketPersistence TrinketDesignSystem)

# Package schemes share one DerivedData build.db — must stay serial.
for package in "${PACKAGES[@]}"; do
  scheme="$(scheme_for_package "$package")"
  echo "=== build-for-testing: $package ($scheme) ==="
  (
    cd "Packages/$package"
    xcodebuild build-for-testing \
      -scheme "$scheme" \
      -sdk iphonesimulator \
      -destination 'generic/platform=iOS Simulator' \
      -derivedDataPath "$DERIVED_DATA_PATH"
  )
done

CI_FINGERPRINTS=(
  unit
  unit_TrinketTests
  smoke
  smoke-full
  ui
  ui_BattleFlowUITests
  ui_TabNavigationUITests_CollectionSearchUITests
  all
)

for fingerprint in "${CI_FINGERPRINTS[@]}"; do
  touch_build_stamp "$RESULTS_DIR" "$fingerprint"
done

echo "=== build-for-testing complete ==="
