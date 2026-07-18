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

# Compile-only: generic simulator destination avoids booting a concrete sim.
xcodebuild build \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  COMPILER_INDEX_STORE_ENABLE=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
