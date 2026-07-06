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

# Build packages in parallel (up to 2 at a time to avoid starving the
# runner). Each package gets its own DerivedData dir since parallel
# xcodebuild invocations cannot safely share one.
max_jobs=2
pids=()
failed=0
index=0
for package in "${PACKAGES[@]}"; do
  (
    cd "Packages/$package"
    xcodebuild build-for-testing \
      -scheme "$package" \
      -sdk iphonesimulator \
      -destination "$SIMULATOR_DESTINATION" \
      -derivedDataPath "$DERIVED_DATA_PATH/${package}Package"
  ) &
  pids+=($!)
  ((index++))
  if (( index % max_jobs == 0 )); then
    for pid in "${pids[@]}"; do
      wait "$pid" || failed=1
    done
    pids=()
  fi
done

for pid in "${pids[@]}"; do
  wait "$pid" || failed=1
done

if [[ "$failed" -ne 0 ]]; then
  echo "ERROR: One or more package builds failed." >&2
  exit 1
fi

for mode in unit smoke ui; do
  touch_build_stamp "$RESULTS_DIR" "$mode"
done

echo "=== build-for-testing complete ==="
