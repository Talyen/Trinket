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

# Bash-level map: package name → scheme that includes its test target.
# Inside each package directory, the test scheme may differ from the
# library-only scheme visible from the workspace root.
scheme_for_package() {
  case "$1" in
    BattleEngine) echo "BattleEngine-Package" ;;
    *) echo "$1" ;;
  esac
}

PACKAGES=(TrinketCore TrinketContent BattleEngine TrinketPersistence TrinketDesignSystem)

# Build each package's test bundle from inside its own directory so the
# correct test-including scheme is resolved, but use the ROOT DerivedData
# path so modules already compiled by the main app build are reused.
for package in "${PACKAGES[@]}"; do
  scheme="$(scheme_for_package "$package")"
  echo "=== build-for-testing: $package ($scheme) ==="
  (
    cd "Packages/$package"
    xcodebuild build-for-testing \
      -scheme "$scheme" \
      -sdk iphonesimulator \
      -destination "$SIMULATOR_DESTINATION" \
      -derivedDataPath "$DERIVED_DATA_PATH"
  )
done

for mode in unit smoke ui; do
  touch_build_stamp "$RESULTS_DIR" "$mode"
done

echo "=== build-for-testing complete ==="
