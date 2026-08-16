#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Make pinned .tools binaries (e.g. xcbeautify) discoverable for verbose output.
if [[ -d "$PWD/.tools" ]]; then
  export PATH="$PWD/.tools:$PATH"
fi

# Must match PRODUCT_BUNDLE_IDENTIFIER in project.yml.
BUNDLE_ID="com.ryanmcintire.Trinket"

# shellcheck source=run-env.sh
source ./Scripts/run-env.sh
trinket_run_env_init
trinket_run_env_print

APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Trinket.app"

# shellcheck source=build-inputs.sh
source ./Scripts/build-inputs.sh
prepare_generated_inputs "$RESULTS_DIR"

# shellcheck source=ensure-simulator.sh
source ./Scripts/ensure-simulator.sh
trinket_sim_slot_ensure

# shellcheck source=xcode-runner.sh
source ./Scripts/xcode-runner.sh
# Compile against a generic destination so xcodebuild does not boot/show a
# concrete simulator. Quiet logs go under TestResults/raw/; print a heartbeat
# so a warm rebuild is not mistaken for a hang.
echo "Building Trinket (quiet; log in $RESULTS_DIR/raw/)..."
xcode_runner_run --label "run-simulator" --quiet -- \
  xcodebuild build \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -parallelizeTargets \
  -disableAutomaticPackageResolution \
  COMPILER_INDEX_STORE_ENABLE=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO

echo "Build succeeded. Preparing Trinket Run..."
ensure_test_simulator

# Prefer simctl ui appearance (no SpringBoard restart). Fall back to defaults write
# only if appearance is unsupported; avoid killall SpringBoard on the warm path.
current_appearance="$(xcrun simctl ui "$SIMULATOR_UDID" appearance 2>/dev/null || true)"
if [[ "$current_appearance" != "dark" ]]; then
  if ! xcrun simctl ui "$SIMULATOR_UDID" appearance dark >/dev/null 2>&1; then
    xcrun simctl spawn "$SIMULATOR_UDID" defaults write com.apple.UIKit UIUserInterfaceStyle -int 2 2>/dev/null || true
  fi
fi

echo "Installing $BUNDLE_ID..."
xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true
# Let install replace an existing app; forced uninstall rewrites ~100MB+ every Run.
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
# Installing a normal app bundle replaces the XCTest-installed app container, so
# invalidate test-without-building stamps that depend on that simulator state.
rm -f "$DERIVED_DATA_PATH"/TestResults/.last-build-*.stamp 2>/dev/null || true

place_bundle_on_first_home_screen() {
  local data_home plist attempt status="missing"
  data_home="$(xcrun simctl getenv "$SIMULATOR_UDID" HOME 2>/dev/null || true)"
  [[ -n "$data_home" ]] || return 0
  plist="$data_home/Library/SpringBoard/IconState.plist"

  for attempt in $(seq 1 15); do
    if [[ -f "$plist" ]]; then
      status="$(python3 ./Scripts/place-home-screen-icon.py --plist "$plist" --bundle-id "$BUNDLE_ID" --check)"
      if [[ "$status" != "missing" ]]; then
        break
      fi
    fi
    sleep 0.2
  done

  status="$(python3 ./Scripts/place-home-screen-icon.py --plist "$plist" --bundle-id "$BUNDLE_ID" --insert-if-missing)"
  printf '%s' "$status"
}

ICON_PLACE_STATUS="$(place_bundle_on_first_home_screen)"
echo "Home screen icon: ${ICON_PLACE_STATUS:-skipped}"
if [[ "$ICON_PLACE_STATUS" == "moved" ]]; then
  # SIGKILL so SpringBoard cannot flush the previous page layout on the way down.
  xcrun simctl spawn "$SIMULATOR_UDID" killall -9 SpringBoard 2>/dev/null || true
fi

echo "Opening Simulator and launching $BUNDLE_ID..."
open -a Simulator --args -CurrentDeviceUDID "$SIMULATOR_UDID"
# Install and a SpringBoard reload can reject the first launch; keep retrying
# until simctl accepts it, then launch once more after SpringBoard settles.
LAUNCH_DEADLINE=$((SECONDS + 20))
until xcrun simctl launch --terminate-running-process \
  "$SIMULATOR_UDID" "$BUNDLE_ID" -- -appearance dark
do
  if (( SECONDS >= LAUNCH_DEADLINE )); then
    echo "error: simctl launch failed for $BUNDLE_ID" >&2
    exit 1
  fi
  sleep 0.4
done
if [[ "$ICON_PLACE_STATUS" == "moved" ]]; then
  sleep 1
  xcrun simctl launch --terminate-running-process \
    "$SIMULATOR_UDID" "$BUNDLE_ID" -- -appearance dark
fi
