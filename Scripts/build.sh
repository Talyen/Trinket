#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Make pinned .tools binaries (e.g. xcbeautify) discoverable for verbose output.
if [[ -d "$PWD/.tools" ]]; then
  export PATH="$PWD/.tools:$PATH"
fi

# shellcheck source=run-env.sh
source ./Scripts/run-env.sh
trinket_run_env_init
trinket_run_env_print

# shellcheck source=build-inputs.sh
source ./Scripts/build-inputs.sh
prepare_generated_inputs "$RESULTS_DIR"

# shellcheck source=xcode-runner.sh
source ./Scripts/xcode-runner.sh

# Compile-only: generic simulator destination avoids booting a concrete sim.
xcode_runner_run --label "app-compile" -- \
  xcodebuild \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -parallelizeTargets \
  -disableAutomaticPackageResolution \
  COMPILER_INDEX_STORE_ENABLE=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
