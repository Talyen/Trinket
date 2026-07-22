#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Resolve the run tenant and simulator before capturing.  `simctl booted` is
# ambiguous once isolated agent slots keep multiple simulators warm.
source ./Scripts/run-env.sh
trinket_run_env_init
source ./Scripts/ensure-simulator.sh
trinket_sim_slot_ensure
ensure_test_simulator

SCREENSHOTS_DIR="${TRINKET_SCREENSHOTS_DIR:-$DERIVED_DATA_PATH/Screenshots}"
mkdir -p "$SCREENSHOTS_DIR"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
OUTPUT_PATH="${1:-$SCREENSHOTS_DIR/simulator-$TIMESTAMP.png}"

mkdir -p "$(dirname "$OUTPUT_PATH")"
xcrun simctl io "$SIMULATOR_UDID" screenshot "$OUTPUT_PATH"
echo "$OUTPUT_PATH"
