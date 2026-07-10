#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA_PATH="$PWD/.DerivedData"
RESULTS_DIR="$DERIVED_DATA_PATH/TestResults"
SCRIPT_DIR="$(dirname "$0")"

source "$SCRIPT_DIR/build-stamp.sh"
# shellcheck source=build-inputs.sh
source "$SCRIPT_DIR/build-inputs.sh"

mkdir -p "$RESULTS_DIR"
prepare_generated_inputs "$RESULTS_DIR"

echo "=== build-for-testing: Trinket app and test bundles ==="
xcodebuild build-for-testing \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_PATH"

PACKAGES=(TrinketCore TrinketContent BattleEngine TrinketPersistence TrinketDesignSystem)

# Package schemes share one DerivedData build.db — must stay serial.
for package in "${PACKAGES[@]}"; do
  echo "=== build-for-testing: $package ==="
  (
    cd "Packages/$package"
    xcodebuild build-for-testing \
      -scheme "$package" \
      -sdk iphonesimulator \
      -destination 'generic/platform=iOS Simulator' \
      -derivedDataPath "$DERIVED_DATA_PATH"
  )
  touch_build_stamp "$RESULTS_DIR" "package_$package"
done

CI_FINGERPRINTS=(
  unit
  unit_TrinketTests
  smoke
  smoke_SmokeHomesteadTests
  smoke_SmokeBattleTests
  smoke_SmokeCollectionTests
  smoke_SmokeHeroDetailTests
  smoke_SmokePlayTests
  smoke_SmokeShopTests
  smoke-full
  ui
  ui_BattleFlowUITests
  ui_TabNavigationUITests_CollectionSearchUITests
  ui_PlayMapUITests_MysteryRecruitUITests
  all
)

for fingerprint in "${CI_FINGERPRINTS[@]}"; do
  touch_build_stamp "$RESULTS_DIR" "$fingerprint"
done

echo "=== build-for-testing complete ==="
