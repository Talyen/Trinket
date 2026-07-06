#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA_PATH="$PWD/.DerivedData"
RESULTS_DIR="$DERIVED_DATA_PATH/TestResults"
SCRIPT_DIR="$(dirname "$0")"

# shellcheck source=build-stamp.sh
source "$SCRIPT_DIR/build-stamp.sh"

GENERIC_DESTINATION="generic/platform=iOS Simulator"

./Scripts/generate.sh
mkdir -p "$RESULTS_DIR"

echo "=== build-for-testing: Trinket app and test bundles ==="
xcodebuild build-for-testing \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -sdk iphonesimulator \
  -destination "$GENERIC_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH"

PACKAGES=(TrinketCore TrinketContent BattleEngine TrinketPersistence TrinketDesignSystem)
for package in "${PACKAGES[@]}"; do
  echo "=== build-for-testing: $package ==="
  (
    cd "Packages/$package"
    xcodebuild build-for-testing \
      -scheme "$package" \
      -sdk iphonesimulator \
      -destination "$GENERIC_DESTINATION" \
      -derivedDataPath "$DERIVED_DATA_PATH/${package}Package"
  )
done

for mode in unit smoke ui; do
  touch_build_stamp "$RESULTS_DIR" "$mode"
done

echo "=== build-for-testing complete ==="
