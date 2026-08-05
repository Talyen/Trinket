#!/usr/bin/env bash
set -euo pipefail

# Creates, boots, and verifies an iOS Simulator for xcodebuild test runs.
# When sourced, sets:
#   SIMULATOR_NAME
#   SIMULATOR_UDID
#   SIMULATOR_DESTINATION   e.g. platform=iOS Simulator,id=...

SIMULATOR_NAME="${TRINKET_SIMULATOR_NAME:-Trinket CI}"
SIMULATOR_BOOT_TIMEOUT_SECONDS="${TRINKET_SIMULATOR_BOOT_TIMEOUT_SECONDS:-150}"

# Prefer shared helper from run-env.sh (callers source run-env before this file).
shutdown_and_wait_simulator() {
  local target_udid="$1"
  [[ -n "$target_udid" ]] || return 0
  if declare -F trinket_sim_shutdown_wait >/dev/null 2>&1; then
    trinket_sim_shutdown_wait "$target_udid"
    return
  fi
  xcrun simctl spawn "$target_udid" launchctl stop com.apple.PosterBoard 2>/dev/null || true
  xcrun simctl shutdown "$target_udid" 2>/dev/null || true
}

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
    return 1
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

  # simctl has no timeout flag, so supervise bootstatus ourselves. Use SECONDS
  # rather than a sleep counter so a busy runner cannot silently extend it.
  xcrun simctl bootstatus "$SIMULATOR_UDID" -b &
  local boot_pid=$!
  local started_at=$SECONDS
  while kill -0 "$boot_pid" 2>/dev/null && (( SECONDS - started_at < SIMULATOR_BOOT_TIMEOUT_SECONDS )); do
    sleep 1
  done
  if kill -0 "$boot_pid" 2>/dev/null; then
    kill "$boot_pid" 2>/dev/null || true
    wait "$boot_pid" 2>/dev/null || true
    echo "Error: Simulator boot timed out after ${SIMULATOR_BOOT_TIMEOUT_SECONDS}s" >&2
    return 1
  fi
  wait "$boot_pid" 2>/dev/null || {
    echo "Error: Simulator boot failed" >&2
    return 1
  }
  echo "$SIMULATOR_NAME ($SIMULATOR_UDID) booted successfully."
}

simulator_matches_name() {
  local udid="$1"
  local expected_name="$2"
  local actual_name
  actual_name="$(xcrun simctl list devices "$udid" -j 2>/dev/null | python3 -c '
import json, sys
payload = json.load(sys.stdin)
for devices in payload.get("devices", {}).values():
    for device in devices:
        if device.get("udid") == sys.argv[1]:
            print(device.get("name", ""))
            sys.exit(0)
sys.exit(1)
' "$udid" 2>/dev/null || true)"
  [[ -n "$actual_name" && "$actual_name" == "$expected_name" ]]
}

ensure_test_simulator() {
  local force="${1:-}"
  local attempt=1
  local max_attempts=2
  local owned_name="${TRINKET_SIMULATOR_NAME:-Trinket CI}"

  # Never shut down or delete a device that does not belong to this run's
  # name. Resolve the actual UDID metadata instead of trusting a caller's
  # cached SIMULATOR_NAME environment value.
  if [[ -n "${SIMULATOR_UDID:-}" ]] && ! simulator_matches_name "$SIMULATOR_UDID" "$owned_name"; then
    echo "Warning: ignoring foreign or unknown simulator $SIMULATOR_UDID; using $owned_name." >&2
    SIMULATOR_UDID=""
  fi
  SIMULATOR_NAME="$owned_name"

  if [[ -n "${SIMULATOR_UDID:-}" && -z "$force" ]]; then
    if boot_simulator; then
      SIMULATOR_DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"
      return 0
    fi
  fi

  if [[ -n "${SIMULATOR_UDID:-}" && -n "$force" ]]; then
    echo "Force-resetting simulator (erase): $SIMULATOR_NAME ($SIMULATOR_UDID)"
    shutdown_and_wait_simulator "$SIMULATOR_UDID"
    if xcrun simctl erase "$SIMULATOR_UDID" 2>/dev/null; then
      if boot_simulator; then
        SIMULATOR_DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"
        echo "Simulator ready after erase: $SIMULATOR_DESTINATION"
        return 0
      fi
    fi
    echo "Erase/reboot failed; deleting simulator and recreating..." >&2
    shutdown_and_wait_simulator "$SIMULATOR_UDID"
    xcrun simctl delete "$SIMULATOR_UDID" 2>/dev/null || true
    SIMULATOR_UDID=""
  fi

  while (( attempt <= max_attempts )); do
    if resolve_or_create_simulator && boot_simulator; then
      SIMULATOR_DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"
      echo "Simulator ready: $SIMULATOR_DESTINATION"
      return 0
    fi

    if (( attempt < max_attempts )); then
      echo "Simulator setup failed; erasing and retrying once..." >&2
      if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
        echo "::warning title=Simulator infrastructure retry::Cold boot failed; retrying once after erase (or recreate)."
      fi
      if [[ -n "${SIMULATOR_UDID:-}" ]]; then
        shutdown_and_wait_simulator "$SIMULATOR_UDID"
        if xcrun simctl erase "$SIMULATOR_UDID" 2>/dev/null && boot_simulator; then
          SIMULATOR_DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"
          echo "Simulator ready after erase retry: $SIMULATOR_DESTINATION"
          return 0
        fi
        shutdown_and_wait_simulator "$SIMULATOR_UDID"
        xcrun simctl delete "$SIMULATOR_UDID" 2>/dev/null || true
        SIMULATOR_UDID=""
      fi
    fi
    ((attempt++))
  done

  echo "Error: Simulator setup failed after ${max_attempts} attempts." >&2
  return 1
}

ensure_test_simulator_logged() {
  local results_dir="${TRINKET_SIMULATOR_LOG_DIR:-${RESULTS_DIR:-}}"
  if [[ -z "$results_dir" ]]; then
    ensure_test_simulator "$@"
    return
  fi

  mkdir -p "$results_dir"
  ensure_test_simulator "$@" > >(tee -a "$results_dir/simulator.log") 2>&1
}
