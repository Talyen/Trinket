#!/usr/bin/env bash
# Build, install, and optionally launch Trinket on a connected physical device.
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh
trinket_prepend_pinned_tools

DEVICE=""
LAUNCH=true
VERBOSE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --device|-d)
      if [[ $# -lt 2 ]]; then echo "--device requires a name, UDID, or identifier" >&2; exit 1; fi
      DEVICE="$2"; shift 2
      ;;
    --no-launch)
      LAUNCH=false; shift
      ;;
    --verbose|-v)
      VERBOSE=true; shift
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/install-device.sh [--device <name|id>] [--no-launch] [--verbose]

Builds Trinket for a connected physical iOS device, installs it, and launches
it in the foreground. Requires a paired device with Developer Mode enabled.

Options:
  --device, -d   Device name, UDID, or CoreDevice identifier (default: first
                 available physical device)
  --no-launch    Install without launching
  --verbose, -v  Show xcodebuild output instead of quiet mode
USAGE
      exit 0
      ;;
    --) shift; break ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) break ;;
  esac
done

if [[ -z "$DEVICE" ]]; then
  DEVICE="$(xcrun devicectl list devices -j - 2>/dev/null | python3 -c '
import json, sys
data = json.load(sys.stdin)
for d in data.get("result", {}).get("devices", []):
    props = d.get("properties", {})
    hw = props.get("hardware", {})
    conn = props.get("connection", {})
    if hw.get("reality") == "physical" and conn.get("pairingState") == "paired":
        print(d["identifier"])
        sys.exit(0)
sys.exit(1)
' 2>/dev/null)" || {
    echo "error: no paired physical device found" >&2
    echo "  Connect an iPhone with Developer Mode enabled and trust this Mac." >&2
    exit 1
  }
  echo "Auto-selected device: $DEVICE"
fi

DERIVED_DATA="$PWD/.DerivedData/Device"
mkdir -p "$DERIVED_DATA"

# shellcheck source=build-freshness.sh
source ./Scripts/build-freshness.sh
prepare_generated_inputs "$DERIVED_DATA/TestResults"

echo "=== Building Trinket for device ==="
# Generic destination keeps the build portable across physical devices so
# --device accepts a name, UDID, or CoreDevice identifier at install time.
source ./Scripts/lib/app-build.sh
trinket_set_app_xcodebuild_args "$DERIVED_DATA" iphoneos 'generic/platform=iOS'
BUILD_ARGS=(
  "${TRINKET_APP_XCODEBUILD_ARGS[@]}"
  -configuration Debug
  -allowProvisioningUpdates
  COMPILER_INDEX_STORE_ENABLE=NO
)

BUILD_LOG="$DERIVED_DATA/install-device-build.log"
if [[ "$VERBOSE" == "true" ]]; then
  set +e
  xcodebuild build "${BUILD_ARGS[@]}" 2>&1 | tee "$BUILD_LOG"
  build_exit=${PIPESTATUS[0]}
  set -e
else
  echo "  (quiet mode; log at $BUILD_LOG)"
  xcodebuild build "${BUILD_ARGS[@]}" >"$BUILD_LOG" 2>&1 || build_exit=$?
  build_exit=${build_exit:-0}
fi

if [[ "${build_exit:-0}" -ne 0 ]]; then
  echo "error: build failed (exit $build_exit)" >&2
  echo "  Log: $BUILD_LOG" >&2
  tail -30 "$BUILD_LOG" >&2 || true
  exit 1
fi
echo "Build succeeded."

APP_PATH="$(find "$DERIVED_DATA/Build/Products" -maxdepth 2 -name 'Trinket.app' -type d -print -quit 2>/dev/null || true)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "error: could not find built Trinket.app under $DERIVED_DATA/Build/Products" >&2
  exit 1
fi

echo "=== Installing on device ==="
xcrun devicectl device install app --device "$DEVICE" "$APP_PATH"

if [[ "$LAUNCH" == "true" ]]; then
  BUNDLE_ID="$(python3 -c '
import plistlib, sys, pathlib
p = pathlib.Path(sys.argv[1]) / "Info.plist"
with open(p, "rb") as f:
    bid = plistlib.load(f).get("CFBundleIdentifier")
if not bid:
    raise SystemExit("no CFBundleIdentifier in built app")
print(bid)
' "$APP_PATH")"

  echo "=== Launching $BUNDLE_ID ==="
  xcrun devicectl device process launch \
    --device "$DEVICE" \
    --terminate-existing \
    "$BUNDLE_ID"
fi

echo "Done."
