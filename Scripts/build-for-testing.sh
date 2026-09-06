#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
SCRIPT_DIR="$(dirname "$0")"

# shellcheck source=run-env.sh
source "$SCRIPT_DIR/run-env.sh"

source "$SCRIPT_DIR/build-freshness.sh"
# shellcheck source=xcode-runner.sh
source "$SCRIPT_DIR/xcode-runner.sh"
# shellcheck source=lib/app-build.sh
source "$SCRIPT_DIR/lib/app-build.sh"

# shellcheck source=lib/args.sh
source "$SCRIPT_DIR/lib/args.sh"
QUIET=true
VERBOSE=false
APP_ONLY=false
while [[ $# -gt 0 ]]; do
  if trinket_args_quiet_verbose "$1"; then shift; continue; fi
  case "$1" in
    --app-only)
      APP_ONLY=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--verbose] [--app-only]"
      exit 0
      ;;
    *)
      trinket_args_unknown "$1" "Usage: $0 [--verbose] [--app-only]" >&2
      exit 1
      ;;
  esac
done

trinket_run_env_init
trinket_run_env_print
trinket_set_app_xcodebuild_args "$DERIVED_DATA_PATH"

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
  "${TRINKET_APP_XCODEBUILD_ARGS[@]}"

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
if ! SKIP_GENERATE=1 ./Scripts/test-package.sh --build-for-testing "${TRINKET_TEST_PACKAGES[@]}"; then
  echo "Package build failed." >&2
  exit 1
fi

for fingerprint in "${TRINKET_BUILD_FINGERPRINTS_FULL[@]}"; do
  touch_build_stamp "$RESULTS_DIR" "$fingerprint"
done

echo "=== build-for-testing complete ==="
