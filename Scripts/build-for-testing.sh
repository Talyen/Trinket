#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

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
REUSE=false
while [[ $# -gt 0 ]]; do
  if trinket_args_quiet_verbose "$1"; then shift; continue; fi
  case "$1" in
    --app-only)
      APP_ONLY=true
      shift
      ;;
    --reuse)
      REUSE=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [--quiet|--verbose] [--app-only] [--reuse]"
      exit 0
      ;;
    *)
      trinket_args_unknown "$1" "Usage: $0 [--quiet|--verbose] [--app-only] [--reuse]" >&2
      exit 1
      ;;
  esac
done

source Scripts/lib/verification-policy.sh
trinket_require_heavy_verification "Build for testing" || exit $?

trinket_run_env_init
trinket_run_env_print
trinket_set_app_xcodebuild_args "$DERIVED_DATA_PATH"

mkdir -p "$RESULTS_DIR"
prepare_generated_inputs "$RESULTS_DIR"

reusable_products() {
  [[ -d "$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Trinket.app" ]] || return 1
  local fingerprints=("${TRINKET_BUILD_FINGERPRINTS_APP[@]}")
  [[ "$APP_ONLY" == true ]] || fingerprints=("${TRINKET_BUILD_FINGERPRINTS_FULL[@]}")
  local fingerprint package products
  for fingerprint in "${fingerprints[@]}"; do
    assert_no_build_inputs_are_fresh "$(build_stamp_path "$RESULTS_DIR" "$fingerprint")" "$fingerprint" || return 1
  done
  if [[ "$APP_ONLY" != true ]]; then
    for package in "${TRINKET_TEST_PACKAGES[@]}"; do
      products="$(package_derived_data_path "$package")/Build/Products"
      compgen -G "$products/*.xctestrun" >/dev/null || return 1
      assert_no_build_inputs_are_fresh "$(build_stamp_path "$RESULTS_DIR" "package_$package")" "package_$package" || return 1
    done
  fi
  compgen -G "$DERIVED_DATA_PATH/Build/Products/*.xctestrun" >/dev/null
}
if [[ "$REUSE" == true ]] && reusable_products; then
  echo "Reusing compatible built products; source snapshots and toolchain match."
  exit 0
fi

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
begin_build_stamps "$RESULTS_DIR" smoke
if [[ "${CI:-}" == true ]]; then
  TRINKET_APP_XCODEBUILD_ARGS+=(-showBuildTimingSummary)
fi
xcode_runner_run "${app_runner_args[@]}" -- xcodebuild build-for-testing \
  "${TRINKET_APP_XCODEBUILD_ARGS[@]}"

if [[ "${CI:-}" == true ]]; then
  # The runner keeps successful build output in a local log; publish the timing
  # summary so hosted builds expose compiler work separately from cache transfer.
  awk '/^Build Timing Summary/ { printing = 1 } printing { print }' "$XCODE_RUNNER_LOG_PATH"
  python3 Scripts/check-localization-build.py --derived-data "$DERIVED_DATA_PATH" \
    --app "$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Trinket.app"
fi

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
