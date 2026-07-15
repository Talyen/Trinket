#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=run-env.sh
source ./Scripts/run-env.sh
trinket_run_env_init
trinket_run_env_print

# shellcheck source=build-inputs.sh
source ./Scripts/build-inputs.sh
prepare_generated_inputs "$RESULTS_DIR"

# shellcheck source=ensure-simulator.sh
source ./Scripts/ensure-simulator.sh
trinket_sim_slot_ensure
ensure_test_simulator

xcodebuild build \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -sdk iphonesimulator \
  -destination "$SIMULATOR_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH"
