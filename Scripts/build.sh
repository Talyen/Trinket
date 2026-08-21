#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh
trinket_prepend_pinned_tools

# shellcheck source=run-env.sh
source ./Scripts/run-env.sh
trinket_run_env_init
trinket_run_env_print

# shellcheck source=build-inputs.sh
source ./Scripts/build-inputs.sh
prepare_generated_inputs "$RESULTS_DIR"

# shellcheck source=xcode-runner.sh
source ./Scripts/xcode-runner.sh
# shellcheck source=lib/app-build.sh
source ./Scripts/lib/app-build.sh
trinket_set_app_xcodebuild_args "$DERIVED_DATA_PATH"

# Compile-only: generic simulator destination avoids booting a concrete sim.
xcode_runner_run --label "app-compile" -- \
  xcodebuild "${TRINKET_APP_XCODEBUILD_ARGS[@]}" \
  COMPILER_INDEX_STORE_ENABLE=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
