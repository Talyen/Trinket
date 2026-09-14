#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh
trinket_prepend_pinned_tools

AGENT_SLOT_ARG=""
INSPECT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --inspect)
      INSPECT=1
      shift
      ;;
    --isolate)
      TRINKET_ISOLATE=1
      export TRINKET_ISOLATE
      shift
      ;;
    --agent)
      if [[ $# -lt 2 ]]; then echo "--agent requires a slot number" >&2; exit 1; fi
      AGENT_SLOT_ARG="$2"
      TRINKET_AGENT_SLOT="$2"
      TRINKET_ISOLATE=1
      export TRINKET_AGENT_SLOT TRINKET_ISOLATE
      shift 2
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/run-simulator.sh [--isolate] [--agent N] [--inspect]

Builds Trinket and launches it. By default targets Trinket Run (human).
Use --isolate for the current agent slot, or --agent N for Trinket Agent N.
Use --inspect in a terminal to hold the lease after launch; type stop to release it.
USAGE
      exit 0
      ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) break ;;
  esac
done

if [[ "$INSPECT" == "1" && ! -t 0 ]]; then
  echo "error: --inspect requires a terminal; agents use exec_command with tty=true." >&2
  exit 1
fi

# shellcheck source=run-env.sh
source ./Scripts/run-env.sh
trinket_run_env_init
trinket_run_env_print

# shellcheck source=build-freshness.sh
source ./Scripts/build-freshness.sh
prepare_generated_inputs "$RESULTS_DIR"

# shellcheck source=ensure-simulator.sh
source ./Scripts/ensure-simulator.sh
trinket_sim_slot_ensure
if [[ "${TRINKET_ISOLATE:-}" != "1" ]]; then
  trinket_shared_sim_lease_acquire
fi

# shellcheck source=xcode-runner.sh
source ./Scripts/xcode-runner.sh
# shellcheck source=lib/app-build.sh
source ./Scripts/lib/app-build.sh
trinket_set_app_xcodebuild_args "$DERIVED_DATA_PATH"
# Compile against a generic destination so xcodebuild does not boot/show a
# concrete simulator. Quiet logs go under TestResults/raw/; print a heartbeat
# so a warm rebuild is not mistaken for a hang.
echo "Building Trinket (quiet; log in $RESULTS_DIR/raw/)..."
xcode_runner_run --label "run-simulator" --quiet -- \
  xcodebuild build "${TRINKET_APP_XCODEBUILD_ARGS[@]}"

BUILD_SETTINGS_PATH="$(mktemp "$RESULTS_DIR/run-simulator-settings.XXXXXX")"
if ! TRINKET_XCODE_WALL_TIMEOUT_SECONDS=60 TRINKET_XCODE_IDLE_TIMEOUT_SECONDS=0 \
  xcode_runner_execute_watched "$BUILD_SETTINGS_PATH.log" "" \
  bash -c 'output=$1; shift; exec "$@" > "$output"' _ "$BUILD_SETTINGS_PATH" \
  xcodebuild -showBuildSettings -json "${TRINKET_APP_XCODEBUILD_ARGS[@]}"; then
  echo "error: could not resolve Trinket build settings; output: $BUILD_SETTINGS_PATH; log: $BUILD_SETTINGS_PATH.log" >&2
  exit 1
fi
if ! APP_PATH="$(python3 - "$BUILD_SETTINGS_PATH" <<'PYSETTINGS'
import json
import pathlib
import sys

try:
    settings = json.loads(pathlib.Path(sys.argv[1]).read_text())
    targets = [entry["buildSettings"] for entry in settings if entry.get("target") == "Trinket"]
    if len(targets) != 1:
        raise ValueError("expected exactly one Trinket app target")
    target = targets[0]
    directory = target.get("TARGET_BUILD_DIR")
    product = target.get("FULL_PRODUCT_NAME")
    if not directory or not product or not product.endswith(".app"):
        raise ValueError("Trinket target lacks TARGET_BUILD_DIR or an app FULL_PRODUCT_NAME")
    app = pathlib.Path(directory) / product
    if not app.is_dir() or not (app / "Info.plist").is_file():
        raise ValueError(f"built app or Info.plist missing: {app}")
    print(app)
except (OSError, ValueError, KeyError, TypeError) as error:
    raise SystemExit(f"error: could not resolve built Trinket app: {error}") from error
PYSETTINGS
)"; then
  echo "Build settings retained: $BUILD_SETTINGS_PATH" >&2
  exit 1
fi
rm -f "$BUILD_SETTINGS_PATH" "$BUILD_SETTINGS_PATH.log"

if [[ -n "${TRINKET_SIMULATOR_NAME:-}" ]]; then
  echo "Build succeeded. Preparing $TRINKET_SIMULATOR_NAME..."
else
  echo "Build succeeded. Preparing Trinket Run..."
fi
ensure_test_simulator

# Read the identifier from the product that was just built so project.yml and
# this launcher cannot silently drift apart.
BUNDLE_ID="$(python3 - "$APP_PATH/Info.plist" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as handle:
    value = plistlib.load(handle).get("CFBundleIdentifier")
if not isinstance(value, str) or not value:
    raise SystemExit("built app Info.plist has no CFBundleIdentifier")
print(value)
PY
)"

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

# Resolve the device UI from the selected Xcode instead of a stale Launch Services
# registration left behind by an Xcode replacement. Xcode 27 uses Device Hub.
SIMULATOR_DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
if [[ -d "$SIMULATOR_DEVELOPER_DIR/Contents/Developer" ]]; then
  SIMULATOR_DEVELOPER_DIR="$SIMULATOR_DEVELOPER_DIR/Contents/Developer"
fi
SIMULATOR_APP_PATH="$(dirname "$SIMULATOR_DEVELOPER_DIR")/Applications/DeviceHub.app"
SIMULATOR_APP_NAME="Device Hub"
if [[ ! -d "$SIMULATOR_APP_PATH" ]]; then
  SIMULATOR_APP_PATH="$SIMULATOR_DEVELOPER_DIR/Applications/Simulator.app"
  SIMULATOR_APP_NAME="Simulator"
fi
SIMULATOR_UI_OPENED=0
if [[ -d "$SIMULATOR_APP_PATH" ]]; then
  if [[ "$SIMULATOR_APP_NAME" == "Device Hub" ]]; then
    if open -a "$SIMULATOR_APP_PATH"; then SIMULATOR_UI_OPENED=1; fi
  elif open -a "$SIMULATOR_APP_PATH" --args -CurrentDeviceUDID "$SIMULATOR_UDID"; then
    SIMULATOR_UI_OPENED=1
  fi
fi
if [[ "$SIMULATOR_UI_OPENED" == "0" ]]; then
  echo "warning: could not open $SIMULATOR_APP_NAME at $SIMULATOR_APP_PATH; launching headlessly" >&2
fi
LAUNCH_DEADLINE=$((SECONDS + 20))
until xcrun simctl launch --terminate-running-process \
  "$SIMULATOR_UDID" "$BUNDLE_ID" -- -appearance dark
do
  if (( SECONDS >= LAUNCH_DEADLINE )); then
    echo "error: simctl launch failed for $BUNDLE_ID" >&2
    echo "  Simulator UDID: $SIMULATOR_UDID ($TRINKET_SIMULATOR_NAME)" >&2
    xcrun simctl list devices "$SIMULATOR_UDID" -j 2>/dev/null | python3 Scripts/simctl_json.py state-for-udid "$SIMULATOR_UDID" 2>/dev/null | sed 's/^/  sim state: /' >&2 || true
    pgrep -a Simulator 2>&1 | sed 's/^/  /' >&2 || echo "  Simulator.app not running" >&2
    exit 1
  fi
  sleep 0.4
done
echo "Launched $BUNDLE_ID on $TRINKET_SIMULATOR_NAME ($SIMULATOR_UDID)."
if [[ "$SIMULATOR_UI_OPENED" == "1" ]]; then
  echo "Opened $SIMULATOR_APP_NAME. Select $TRINKET_SIMULATOR_NAME ($SIMULATOR_UDID) and confirm its screen before interacting."
fi

if [[ "$INSPECT" == "1" ]]; then
  printf 'Inspection ready: %s (%s)\nApp: %s\nProduct: %s\n' \
    "$TRINKET_SIMULATOR_NAME" "$SIMULATOR_UDID" "$BUNDLE_ID" "$APP_PATH"
  echo "Device UI: $SIMULATOR_APP_NAME ($SIMULATOR_APP_PATH)"
  echo "Lease held by this process. Use computer use on this simulator; type stop here when finished."
  while IFS= read -r inspection_command; do
    [[ "$inspection_command" == "stop" ]] && break
    echo "Inspection still active. Type stop to release the lease."
  done
  echo "Inspection finished; releasing this process's lease."
fi
