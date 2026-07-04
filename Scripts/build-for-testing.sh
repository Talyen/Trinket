#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA_PATH="$PWD/.DerivedData"
RESULTS_DIR="$DERIVED_DATA_PATH/TestResults"

./Scripts/generate.sh
mkdir -p "$RESULTS_DIR"

IOS_BUILD_DESTINATION="generic/platform=iOS Simulator"

echo "=== build-for-testing: Trinket app and test bundles ==="
xcodebuild build-for-testing \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -sdk iphonesimulator \
  -destination "$IOS_BUILD_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH"

PACKAGES=(TrinketCore TrinketContent BattleEngine TrinketPersistence TrinketDesignSystem)
for package in "${PACKAGES[@]}"; do
  echo "=== build-for-testing: $package ==="
  (
    cd "Packages/$package"
    xcodebuild build-for-testing \
      -scheme "$package" \
      -sdk iphonesimulator \
      -destination "$IOS_BUILD_DESTINATION" \
      -derivedDataPath "$DERIVED_DATA_PATH/${package}Package"
  )
done

for mode in unit smoke ui; do
  touch "$RESULTS_DIR/.last-build-${mode}.stamp"
done

echo "=== build-for-testing complete ==="
