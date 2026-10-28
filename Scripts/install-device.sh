#!/usr/bin/env bash
# Build, install, and optionally launch Trinket on a connected physical device.
set -euo pipefail
TRINKET_ENTRY_ARGS=("$@")

cd "$(dirname "$0")/.."
# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh
trinket_prepend_pinned_tools

DEVICE=""
LAUNCH=true
VERBOSE=false
DEVICE_BUILD_CONFIGURATION=Debug
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
    --release)
      DEVICE_BUILD_CONFIGURATION=Release; shift
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/install-device.sh [--device <name|id>] [--release] [--no-launch] [--verbose]

Builds Trinket for a connected physical iOS device, installs it, and launches
it in the foreground. Requires a paired device with Developer Mode enabled.

Options:
  --device, -d   Device name, UDID, or CoreDevice identifier (default: first
                 available physical device)
  --no-launch    Install without launching
  --release      Build optimized Release configuration for device performance checks
  --verbose, -v  Show xcodebuild output instead of quiet mode
USAGE
      exit 0
      ;;
    --) shift; break ;;
    -*) echo "Unknown argument: $1" >&2; exit 1 ;;
    *) break ;;
  esac
done

source Scripts/lib/verification-policy.sh
trinket_host_admit "$PWD/Scripts/install-device.sh" "${TRINKET_ENTRY_ARGS[@]+"${TRINKET_ENTRY_ARGS[@]}"}" || exit $?

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

# Join the shared run tenant (diagnostics session, lock/result defaults) like
# every other build entry point; device products stay in DERIVED_DATA above.
# shellcheck source=run-env.sh
source ./Scripts/run-env.sh
trinket_run_env_init
trinket_run_env_print

# shellcheck source=build-freshness.sh
source ./Scripts/build-freshness.sh
prepare_generated_inputs "$DERIVED_DATA/TestResults"

echo "=== Building Trinket for device ($DEVICE_BUILD_CONFIGURATION) ==="
# Generic destination keeps the build portable across physical devices so
# --device accepts a name, UDID, or CoreDevice identifier at install time.
source ./Scripts/lib/app-build.sh
trinket_set_app_xcodebuild_args "$DERIVED_DATA" iphoneos 'generic/platform=iOS' "$DEVICE_BUILD_CONFIGURATION"
BUILD_ARGS=(
  "${TRINKET_APP_XCODEBUILD_ARGS[@]}"
  -allowProvisioningUpdates
  COMPILER_INDEX_STORE_ENABLE=NO
  ENABLE_CODE_COVERAGE=NO
)

BUILD_LOG="$DERIVED_DATA/install-device-build.log"
source ./Scripts/xcode-runner.sh
xcode_runner_prepare install-device "$DERIVED_DATA/TestResults"
verbosity=--quiet
[[ "$VERBOSE" == false ]] || verbosity=--verbose
xcode_runner_run --label install-device --log "$BUILD_LOG" \
  --result-bundle "$XCODE_RUNNER_RESULT_BUNDLE_PATH" \
  --report-prefix "$XCODE_RUNNER_REPORT_PREFIX" "$verbosity" -- \
  xcodebuild build "${BUILD_ARGS[@]}"

echo "Build succeeded."

APP_PATH="$DERIVED_DATA/Build/Products/$DEVICE_BUILD_CONFIGURATION-iphoneos/Trinket.app"
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
