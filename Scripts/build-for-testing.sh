#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
SCRIPT_DIR="$(dirname "$0")"

# shellcheck source=run-env.sh
source "$SCRIPT_DIR/run-env.sh"
trinket_run_env_init
trinket_run_env_print
# Isolated builds share a warm agent-N DerivedData tenant; no simulator boot needed
# (generic/platform destination), but init already acquired the agent slot.

source "$SCRIPT_DIR/build-stamp.sh"
# shellcheck source=build-inputs.sh
source "$SCRIPT_DIR/build-inputs.sh"
# shellcheck source=xcode-runner.sh
source "$SCRIPT_DIR/xcode-runner.sh"

QUIET=true
APP_ONLY=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose|verbose)
      QUIET=false
      shift
      ;;
    --quiet|quiet)
      QUIET=true
      shift
      ;;
    --app-only)
      APP_ONLY=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--verbose] [--app-only]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--verbose] [--app-only]" >&2
      exit 1
      ;;
  esac
done

mkdir -p "$RESULTS_DIR"
prepare_generated_inputs "$RESULTS_DIR"

echo "=== build-for-testing: Trinket app and test bundles ==="
xcode_runner_prepare "build-app" "$RESULTS_DIR"
app_runner_args=(
  --label build-app
  --result-bundle "$XCODE_RUNNER_RESULT_BUNDLE_PATH"
  --log "$XCODE_RUNNER_LOG_PATH"
  --report-prefix "$XCODE_RUNNER_REPORT_PREFIX"
)
if [[ "$QUIET" == "true" ]]; then
  app_runner_args+=(--quiet)
else
  app_runner_args+=(--verbose)
fi
# Build-only invocations do not write a result bundle; logs + manifests carry
# the outcome and test runs produce their own xcresults.
xcode_runner_run "${app_runner_args[@]}" -- xcodebuild build-for-testing \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -parallelizeTargets \
  -disableAutomaticPackageResolution

if [[ "$APP_ONLY" == "true" ]]; then
  echo "=== build-for-testing: skipping package schemes (--app-only) ==="
  for fingerprint in "${TRINKET_BUILD_FINGERPRINTS_APP[@]}"; do
    touch_build_stamp "$RESULTS_DIR" "$fingerprint"
  done
  echo "=== build-for-testing complete (app-only) ==="
  exit 0
fi

# Package schemes use per-package DerivedData tenants so they can build in
# parallel without contending on a shared build.db. test-package.sh owns the
# single parallel implementation shared with test.sh. App products stay in
# DERIVED_DATA_PATH; package test products live under packages/<name>/.
echo "=== build-for-testing: package schemes (parallel) ==="
if ! ./Scripts/test-package.sh --build-for-testing "${TRINKET_TEST_PACKAGES[@]}"; then
  echo "Package build failed." >&2
  exit 1
fi

for fingerprint in "${TRINKET_BUILD_FINGERPRINTS_FULL[@]}"; do
  touch_build_stamp "$RESULTS_DIR" "$fingerprint"
done

echo "=== build-for-testing complete ==="
