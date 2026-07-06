#!/usr/bin/env bash
set -euo pipefail

# Creates, boots, and verifies an iOS Simulator for xcodebuild test runs.
# When sourced, sets:
#   SIMULATOR_NAME
#   SIMULATOR_UDID
#   SIMULATOR_DESTINATION   e.g. platform=iOS Simulator,id=...

SIMULATOR_NAME="Trinket CI"
SIMULATOR_PREFERRED_DEVICE="iPhone 17 Pro"

resolve_or_create_simulator() {
  SIMULATOR_UDID="$(xcrun simctl list devices available -j 2>/dev/null | python3 -c '
import json, sys
payload = json.load(sys.stdin)
for devices in payload.get("devices", {}).values():
    for device in devices:
        if device.get("name") == sys.argv[1]:
            print(device.get("udid"))
            sys.exit(0)
sys.exit(1)
' "$SIMULATOR_NAME" 2>/dev/null || true)"

  if [[ -n "${SIMULATOR_UDID:-}" ]]; then
    echo "Using existing simulator: $SIMULATOR_NAME ($SIMULATOR_UDID)"
    return 0
  fi

  echo "Creating new simulator: $SIMULATOR_NAME ($SIMULATOR_PREFERRED_DEVICE)"

  local runtime
  runtime="$(xcrun simctl list runtimes available 2>/dev/null \
    | grep -E "^iOS " \
    | head -1 \
    | awk '{print $NF}')"

  local device_type
  device_type="$(xcrun simctl list devicetypes 2>/dev/null \
    | grep -F "$SIMULATOR_PREFERRED_DEVICE" \
    | head -1 \
    | sed -n 's/.*(\(.*\)).*/\1/p')"

  if [[ -z "${device_type:-}" ]]; then
    device_type="$(xcrun simctl list devicetypes 2>/dev/null \
      | grep -F "iPhone" \
      | head -1 \
      | sed -n 's/.*(\(.*\)).*/\1/p')"
  fi

  SIMULATOR_UDID="$(xcrun simctl create "$SIMULATOR_NAME" "$device_type" "$runtime")"
  echo "Created simulator: $SIMULATOR_NAME ($SIMULATOR_UDID)"
}

boot_simulator() {
  local state
  state="$(xcrun simctl list devices "$SIMULATOR_UDID" -j 2>/dev/null | python3 -c '
import json, sys
payload = json.load(sys.stdin)
for devices in payload.get("devices", {}).values():
    for device in devices:
        if device.get("udid") == sys.argv[1]:
            print(device.get("state"))
            sys.exit(0)
sys.exit(1)
' "$SIMULATOR_UDID" 2>/dev/null || echo "Unknown")"

  if [[ "$state" == "Booted" ]]; then
    echo "$SIMULATOR_NAME ($SIMULATOR_UDID) is already booted."
    return 0
  fi

  echo "Booting $SIMULATOR_NAME ($SIMULATOR_UDID)..."
  xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true

  # Bootstatus with timeout to avoid hanging CI (120s)
  xcrun simctl bootstatus "$SIMULATOR_UDID" -b &
  local boot_pid=$!
  local wait_seconds=0
  while kill -0 "$boot_pid" 2>/dev/null && (( wait_seconds < 120 )); do
    sleep 2
    ((wait_seconds+=2))
  done
  if kill -0 "$boot_pid" 2>/dev/null; then
    kill "$boot_pid" 2>/dev/null || true
    wait "$boot_pid" 2>/dev/null || true
    echo "Error: Simulator boot timed out after 120s" >&2
    exit 1
  fi
  wait "$boot_pid" 2>/dev/null || {
    echo "Error: Simulator boot failed" >&2
    exit 1
  }
  echo "$SIMULATOR_NAME ($SIMULATOR_UDID) booted successfully."
}

ensure_test_simulator() {
  local force="${1:-}"

  if [[ -n "${SIMULATOR_UDID:-}" && -z "$force" ]]; then
    boot_simulator
    SIMULATOR_DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"
    return 0
  fi

  if [[ -n "$force" && -n "${SIMULATOR_UDID:-}" ]]; then
    echo "Force-resetting simulator: $SIMULATOR_NAME ($SIMULATOR_UDID)"
    xcrun simctl shutdown "$SIMULATOR_UDID" 2>/dev/null || true
    xcrun simctl delete "$SIMULATOR_UDID" 2>/dev/null || true
    SIMULATOR_UDID=""
  fi

  resolve_or_create_simulator
  boot_simulator
  SIMULATOR_DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"
  echo "Simulator ready: $SIMULATOR_DESTINATION"
}

destination_for_udid() {
  echo "platform=iOS Simulator,id=$1"
}
