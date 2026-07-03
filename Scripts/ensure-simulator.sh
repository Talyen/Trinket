#!/bin/zsh
set -euo pipefail

# Resolves, creates if needed, boots, and verifies an iOS Simulator for xcodebuild.
# When sourced, sets:
#   SIMULATOR_NAME
#   SIMULATOR_UDID
#   SIMULATOR_DESTINATION   e.g. platform=iOS Simulator,id=...
#   SIMULATOR_POOL_UDIDS    populated by ensure_simulator_pool

SIMULATOR_POOL_UDIDS=()

PREFERRED_SIMULATOR_NAMES=(
  "iPhone 17 Pro"
  "iPhone 16 Pro"
  "iPhone 15 Pro"
)

resolve_simulator() {
  local force="${1:-}"

  if [[ -n "${SIMULATOR_UDID:-}" && -z "$force" ]]; then
    return 0
  fi

  local resolved
  resolved="$(
    python3 - "${PREFERRED_SIMULATOR_NAMES[@]}" <<'PY'
import json
import subprocess
import sys
from typing import List, Optional

preferred = sys.argv[1:]


def simctl_json(*args: str) -> dict:
    return json.loads(subprocess.check_output(["xcrun", "simctl", *args], text=True))


def list_available_devices() -> List[dict]:
    payload = simctl_json("list", "devices", "available", "-j")
    devices: List[dict] = []
    for runtime, runtime_devices in payload.get("devices", {}).items():
        if "iOS" not in runtime:
            continue
        for device in runtime_devices:
            if device.get("isAvailable", True):
                devices.append(device)
    return devices


def pick_device(devices: List[dict]) -> Optional[dict]:
    by_name = {device.get("name", ""): device for device in devices}
    for name in preferred:
        if name in by_name:
            return by_name[name]

    for device in devices:
        name = device.get("name", "")
        if name.startswith("iPhone"):
            return device
    return None


def latest_ios_runtime_id() -> str:
    payload = simctl_json("list", "runtimes", "available", "-j")
    ios_runtimes = [
        runtime
        for runtime in payload.get("runtimes", [])
        if runtime.get("platform") == "iOS" and runtime.get("isAvailable", True)
    ]
    if not ios_runtimes:
        raise SystemExit("No available iOS simulator runtime found.")
    ios_runtimes.sort(key=lambda runtime: runtime.get("version", ""), reverse=True)
    return ios_runtimes[0]["identifier"]


def device_type_id(name: str) -> str:
    payload = simctl_json("list", "devicetypes", "-j")
    for device_type in payload.get("devicetypes", []):
        if device_type.get("name") == name:
            return device_type["identifier"]
    raise SystemExit(f"No simulator device type found for '{name}'.")


devices = list_available_devices()
device = pick_device(devices)

if device is None:
    target_name = preferred[0]
    runtime_id = latest_ios_runtime_id()
    type_id = device_type_id(target_name)
    udid = subprocess.check_output(
        ["xcrun", "simctl", "create", target_name, type_id, runtime_id],
        text=True,
    ).strip()
    print(f"{target_name}\t{udid}")
    sys.exit(0)

name = device.get("name", "")
udid = device.get("udid", "")
if not name or not udid:
    raise SystemExit("Resolved simulator is missing name or UDID.")
print(f"{name}\t{udid}")
PY
  )"

  SIMULATOR_NAME="${resolved%%$'\t'*}"
  SIMULATOR_UDID="${resolved#*$'\t'}"
  SIMULATOR_DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"
}

boot_simulator_udid() {
  local udid="$1"
  local name="${2:-Simulator}"
  local state
  state="$(xcrun simctl list devices "$udid" | awk -F '[()]' '/\('"${udid}"'\)/ {print $2}')"

  if [[ "$state" != "Booted" ]]; then
    echo "Booting $name ($udid)..."
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" -b
  else
    echo "$name ($udid) is already booted."
  fi
}

boot_simulator() {
  boot_simulator_udid "$SIMULATOR_UDID" "$SIMULATOR_NAME"
}

destination_for_udid() {
  echo "platform=iOS Simulator,id=$1"
}

verify_simulator_destination() {
  if ! xcrun simctl list devices booted -j | python3 -c '
import json, sys
udid = sys.argv[1]
payload = json.load(sys.stdin)
for devices in payload.get("devices", {}).values():
    for device in devices:
        if device.get("udid") == udid and device.get("state") == "Booted":
            raise SystemExit(0)
raise SystemExit(1)
' "$SIMULATOR_UDID"; then
    echo "Simulator $SIMULATOR_UDID is not booted after bootstatus." >&2
    return 1
  fi

  if ! xcodebuild -showdestinations \
    -project Trinket.xcodeproj \
    -scheme Trinket 2>/dev/null | grep -Fq "id:$SIMULATOR_UDID"; then
    echo "xcodebuild does not list simulator destination id:$SIMULATOR_UDID" >&2
    return 1
  fi

  echo "Verified xcodebuild destination: $SIMULATOR_DESTINATION"
}

ensure_test_simulator() {
  local force="${1:-}"
  resolve_simulator "$force"
  boot_simulator
  verify_simulator_destination
}

ensure_simulator_pool() {
  local count="${1:-1}"

  if (( count < 1 )); then
    echo "Simulator pool count must be >= 1." >&2
    return 1
  fi

  SIMULATOR_POOL_UDIDS=()
  ensure_test_simulator
  SIMULATOR_POOL_UDIDS+=("$SIMULATOR_UDID")

  local index
  for (( index = 2; index <= count; index++ )); do
    local clone_name="Trinket CI ${SIMULATOR_NAME} ${index}"
    local clone_udid
    clone_udid="$(xcrun simctl clone "$SIMULATOR_UDID" "$clone_name")"
    boot_simulator_udid "$clone_udid" "$clone_name"
    SIMULATOR_POOL_UDIDS+=("$clone_udid")
  done

  echo "Simulator pool (${#SIMULATOR_POOL_UDIDS[@]}): ${SIMULATOR_POOL_UDIDS[*]}"
}
