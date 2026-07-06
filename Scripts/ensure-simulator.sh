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

  echo "Creating new simulator named '$SIMULATOR_NAME'..."

  local resolved
  resolved="$(python3 - "$SIMULATOR_NAME" <<'PY'
import json, subprocess, sys

def simctl_json(*args):
    return json.loads(subprocess.check_output(["xcrun", "simctl", *args], text=True))

devices_payload = simctl_json("list", "devices", "available", "-j")
runtimes_payload = simctl_json("list", "runtimes", "available", "-j")

ios_runtimes = [
    r for r in runtimes_payload.get("runtimes", [])
    if r.get("platform") == "iOS" and r.get("isAvailable", True)
]
if not ios_runtimes:
    sys.exit(1)
ios_runtimes.sort(key=lambda r: r.get("version", ""), reverse=True)
runtime_id = ios_runtimes[0]["identifier"]

compatible_devices = devices_payload.get("devices", {}).get(runtime_id, [])
compatible_types = {}
for d in compatible_devices:
    type_id = d.get("deviceTypeIdentifier")
    name = d.get("name")
    if type_id and name:
        compatible_types[type_id] = name

preferred = ["iPhone 17 Pro", "iPhone 16 Pro", "iPhone 15 Pro"]
chosen_type_id = None

for name in preferred:
    for type_id, comp_name in compatible_types.items():
        if name in comp_name:
            chosen_type_id = type_id
            break
    if chosen_type_id:
        break

if not chosen_type_id:
    for type_id, comp_name in compatible_types.items():
        if "iPhone" in comp_name and "Pro" in comp_name:
            chosen_type_id = type_id
            break

if not chosen_type_id:
    for type_id, comp_name in compatible_types.items():
        if "iPhone" in comp_name:
            chosen_type_id = type_id
            break

if not chosen_type_id and compatible_types:
    chosen_type_id = list(compatible_types.keys())[0]

if not chosen_type_id:
    sys.exit(1)

sim_name = sys.argv[1]
udid = subprocess.check_output(["xcrun", "simctl", "create", sim_name, chosen_type_id, runtime_id], text=True).strip()
print(f"{udid}\t{chosen_type_id}\t{runtime_id}")
PY
)"

  if [[ -z "${resolved:-}" || "$resolved" != *$'\t'* ]]; then
    echo "Error: Failed to resolve and create compatible simulator." >&2
    exit 1
  fi

  SIMULATOR_UDID="${resolved%%$'\t'*}"
  local dev_type_id="${resolved#*$'\t'}"
  dev_type_id="${dev_type_id%%$'\t'*}"
  local rt_id="${resolved##*$'\t'}"

  echo "Created simulator: $SIMULATOR_NAME ($SIMULATOR_UDID) using type $dev_type_id and runtime $rt_id"
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
