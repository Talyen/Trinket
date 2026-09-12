#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
source Scripts/run-env.sh
source Scripts/build-freshness.sh
source Scripts/xcode-runner.sh
source Scripts/lib/app-build.sh
source Scripts/lib/args.sh

QUIET=true
VERBOSE=false
RELEASE_DEVICE=false
while [[ $# -gt 0 ]]; do
  if trinket_args_quiet_verbose "$1"; then shift; continue; fi
  case "$1" in
    --release-device) RELEASE_DEVICE=true ;;
    --help|-h)
      echo "Usage: $0 [--quiet|--verbose] [--release-device]"
      echo "Compile the app only; --release-device checks unsigned iOS Release compilation."
      exit 0 ;;
    *) trinket_args_unknown "$1" "Usage: $0 [--quiet|--verbose] [--release-device]"; exit 1 ;;
  esac
  shift
done

trinket_run_env_init
trinket_run_env_print
prepare_generated_inputs "$RESULTS_DIR"
trinket_set_app_xcodebuild_args "$DERIVED_DATA_PATH"
label=compile-app
if [[ "$RELEASE_DEVICE" == true ]]; then
  trinket_set_app_xcodebuild_args "$DERIVED_DATA_PATH/release-device" iphoneos 'generic/platform=iOS'
  TRINKET_APP_XCODEBUILD_ARGS+=(-configuration Release CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO)
  label=compile-release-device
fi
xcode_runner_prepare "$label" "$RESULTS_DIR"
verbosity=--quiet
[[ "$QUIET" == true ]] || verbosity=--verbose
xcode_runner_run --label "$label" --log "$XCODE_RUNNER_LOG_PATH" \
  --report-prefix "$XCODE_RUNNER_REPORT_PREFIX" "$verbosity" -- \
  xcodebuild build "${TRINKET_APP_XCODEBUILD_ARGS[@]}"
