#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA_PATH="$PWD/.DerivedData"
RESULTS_DIR="$DERIVED_DATA_PATH/TestResults"
SCRIPT_DIR="$(dirname "$0")"

# shellcheck source=build-stamp.sh
source "$SCRIPT_DIR/build-stamp.sh"
# shellcheck source=ensure-simulator.sh
source "$SCRIPT_DIR/ensure-simulator.sh"

./Scripts/generate.sh
ensure_test_simulator
mkdir -p "$RESULTS_DIR"

echo "=== build-for-testing: Trinket app and test bundles ==="
xcodebuild build-for-testing \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -sdk iphonesimulator \
  -destination "$SIMULATOR_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH"

PACKAGES=(TrinketCore TrinketContent BattleEngine TrinketPersistence TrinketDesignSystem)

# Build each package's test bundle from the workspace root with the same
# DerivedData as the main app. The app build already compiled all package
# modules, so each package build only compiles its test targets.
for package in "${PACKAGES[@]}"; do
  echo "=== build-for-testing: $package (test bundles) ==="
  xcodebuild build-for-testing \
    -scheme "$package" \
    -project Trinket.xcodeproj \
    -sdk iphonesimulator \
    -destination "$SIMULATOR_DESTINATION" \
    -derivedDataPath "$DERIVED_DATA_PATH"
done

for mode in unit smoke ui; do
  touch_build_stamp "$RESULTS_DIR" "$mode"
done

echo "=== build-for-testing complete ==="
