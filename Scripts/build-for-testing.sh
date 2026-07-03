#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA_PATH="$PWD/.DerivedData"
RESULTS_DIR="$DERIVED_DATA_PATH/TestResults"
SCRIPT_DIR="$(dirname "$0")"

# shellcheck source=ensure-simulator.sh
source "$SCRIPT_DIR/ensure-simulator.sh"

./Scripts/generate.sh
ensure_test_simulator
mkdir -p "$RESULTS_DIR"

echo "=== build-for-testing: Trinket app and test bundles ==="
xcodebuild build-for-testing \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -destination "$SIMULATOR_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH"

PACKAGES=(TrinketCore TrinketContent BattleEngine TrinketPersistence TrinketDesignSystem)
for package in "${PACKAGES[@]}"; do
  echo "=== build-for-testing: $package ==="
  (
    cd "Packages/$package"
    xcodebuild build-for-testing \
      -scheme "$package" \
      -destination "$SIMULATOR_DESTINATION" \
      -derivedDataPath "$DERIVED_DATA_PATH/${package}Package"
  )
done

for mode in unit smoke ui; do
  touch "$RESULTS_DIR/.last-build-${mode}.stamp"
done

echo "=== build-for-testing complete ==="
