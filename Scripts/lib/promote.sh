#!/usr/bin/env bash
# Install the current run's app on Trinket Run while the caller holds both leases.

trinket_promote_auto_mirror_to_run() (
  local src_app="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Trinket.app"
  if [[ ! -d "$src_app" ]]; then
    echo "Mirror failed: built app missing at $src_app" >&2
    return 1
  fi

  local bundle_id
  bundle_id="$(python3 - "$src_app/Info.plist" <<'PLIST'
import plistlib
import sys

with open(sys.argv[1], "rb") as stream:
    identifier = plistlib.load(stream).get("CFBundleIdentifier")
if not isinstance(identifier, str) or not identifier:
    raise SystemExit("Mirror failed: app has no CFBundleIdentifier")
print(identifier)
PLIST
)" || return 1

  TRINKET_SIMULATOR_NAME="Trinket Run"
  source Scripts/ensure-simulator.sh
  resolve_or_create_simulator || return 1
  boot_simulator || return 1
  echo "Mirror: installing $src_app on Trinket Run ($SIMULATOR_UDID)..."
  xcrun simctl install "$SIMULATOR_UDID" "$src_app" || return 1
  if [[ "${TRINKET_HANDOFF_AUTO_LAUNCH:-0}" == "1" ]]; then
    xcrun simctl launch --terminate-running-process "$SIMULATOR_UDID" "$bundle_id" -- -appearance dark || return 1
  fi
  echo "Mirror complete: Trinket Run has the current build."
)
