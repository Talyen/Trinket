#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
DERIVED_DATA_PATH="$PWD/.DerivedData"
RESULTS_DIR="$DERIVED_DATA_PATH/TestResults"
SCRIPT_DIR="$(dirname "$0")"

source "$SCRIPT_DIR/build-stamp.sh"
# shellcheck source=build-inputs.sh
source "$SCRIPT_DIR/build-inputs.sh"
# shellcheck source=xcode-runner.sh
source "$SCRIPT_DIR/xcode-runner.sh"

QUIET=true
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
    --help|-h)
      echo "Usage: $0 [--verbose]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--verbose]" >&2
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
xcode_runner_run "${app_runner_args[@]}" -- xcodebuild build-for-testing \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$XCODE_RUNNER_RESULT_BUNDLE_PATH"

PACKAGES=(TrinketCore TrinketContent BattleEngine TrinketPersistence TrinketDesignSystem)

# Package schemes share one DerivedData build.db — must stay serial.
for package in "${PACKAGES[@]}"; do
  echo "=== build-for-testing: $package ==="
  xcode_runner_prepare "build-package-$package" "$RESULTS_DIR"
  package_runner_args=(
    --label "build-package-$package"
    --result-bundle "$XCODE_RUNNER_RESULT_BUNDLE_PATH"
    --log "$XCODE_RUNNER_LOG_PATH"
    --report-prefix "$XCODE_RUNNER_REPORT_PREFIX"
    --working-directory "$PWD/Packages/$package"
  )
  if [[ "$QUIET" == "true" ]]; then
    package_runner_args+=(--quiet)
  else
    package_runner_args+=(--verbose)
  fi
  xcode_runner_run "${package_runner_args[@]}" -- xcodebuild build-for-testing \
    -scheme "$(package_test_scheme "$package")" \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -resultBundlePath "$XCODE_RUNNER_RESULT_BUNDLE_PATH"
  touch_build_stamp "$RESULTS_DIR" "package_$package"
done

CI_FINGERPRINTS=(
  unit
  unit_TrinketTests
  smoke
  smoke_SmokeHomesteadTests
  smoke_SmokeBattleTests
  smoke_SmokeCollectionTests
  smoke_SmokeHeroDetailTests
  smoke_SmokePlayTests
  smoke_SmokeShopTests
  smoke-full
  ui
  ui_BattleFlowUITests
  ui_TabNavigationUITests_CollectionSearchUITests
  ui_PlayMapUITests_MysteryRecruitUITests
  all
)

for fingerprint in "${CI_FINGERPRINTS[@]}"; do
  touch_build_stamp "$RESULTS_DIR" "$fingerprint"
done

echo "=== build-for-testing complete ==="
