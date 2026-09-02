#!/usr/bin/env bash
# Shared helper: mirror an isolated agent build to the human "Trinket Run" simulator.
# Install-only — no relaunch — so a mid-session game is not killed.

trinket_promote_auto_mirror_to_run() {
  if [[ "${TRINKET_ISOLATE:-}" != "1" ]]; then
    return 0
  fi
  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    return 0
  fi
  if [[ "${TRINKET_PROMOTE_SKIP:-0}" == "1" ]]; then
    return 0
  fi

  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  local src_app="${DERIVED_DATA_PATH:-}/Build/Products/Debug-iphonesimulator/Trinket.app"
  if [[ -z "${DERIVED_DATA_PATH:-}" || ! -d "$src_app" ]]; then
    if [[ -n "${TRINKET_AGENT_SLOT:-}" ]]; then
      src_app="$repo_root/.DerivedData/runs/agent-${TRINKET_AGENT_SLOT}/Build/Products/Debug-iphonesimulator/Trinket.app"
    fi
    if [[ ! -d "$src_app" ]]; then
      local best="" cand mtime best_mtime=0
      for cand in "$repo_root"/.DerivedData/runs/agent-*/Build/Products/Debug-iphonesimulator/Trinket.app "$repo_root/.DerivedData/Build/Products/Debug-iphonesimulator/Trinket.app"; do
        [[ -d "$cand" ]] || continue
        mtime="$(stat -f %m "$cand" 2>/dev/null || stat -c %Y "$cand" 2>/dev/null || echo 0)"
        if (( mtime > best_mtime )); then
          best_mtime="$mtime"
          best="$cand"
        fi
      done
      if [[ -n "$best" ]]; then
        src_app="$best"
      fi
    fi
  fi
  if [[ ! -d "$src_app" ]]; then
    echo "Auto-mirror: Trinket.app missing — building for mirror..."
    if ! env SKIP_GENERATE=1 ./Scripts/build.sh >/dev/null 2>&1; then
      echo "warning: auto-mirror build failed; skipping install to Trinket Run" >&2
      return 0
    fi
    local best2="" cand2 mtime2 best_mtime2=0
    for cand2 in "$repo_root"/.DerivedData/runs/agent-*/Build/Products/Debug-iphonesimulator/Trinket.app "$repo_root/.DerivedData/Build/Products/Debug-iphonesimulator/Trinket.app"; do
      [[ -d "$cand2" ]] || continue
      mtime2="$(stat -f %m "$cand2" 2>/dev/null || stat -c %Y "$cand2" 2>/dev/null || echo 0)"
      if (( mtime2 > best_mtime2 )); then
        best_mtime2="$mtime2"
        best2="$cand2"
      fi
    done
    if [[ -n "$best2" ]]; then
      src_app="$best2"
    fi
  fi
  if [[ ! -d "$src_app" ]]; then
    echo "warning: auto-mirror: app still missing after build at $src_app" >&2
    return 0
  fi

  local bundle_id
  bundle_id="$(python3 - "$src_app/Info.plist" <<'PY' 2>/dev/null || true
import plistlib
import sys
try:
    with open(sys.argv[1], "rb") as h:
        v = plistlib.load(h).get("CFBundleIdentifier")
    if isinstance(v, str) and v:
        print(v)
except Exception:
    pass
PY
)"
  if [[ -z "$bundle_id" ]]; then
    echo "warning: auto-mirror could not read CFBundleIdentifier from $src_app" >&2
    return 0
  fi

  local run_name="Trinket Run"
  local run_udid=""
  run_udid="$(xcrun simctl list devices available -j 2>/dev/null | python3 "$repo_root/Scripts/simctl_json.py" udid-for-name "$run_name" 2>/dev/null || true)"
  if [[ -z "$run_udid" ]]; then
    local prev_name="${TRINKET_SIMULATOR_NAME:-}"
    TRINKET_SIMULATOR_NAME="$run_name"
    local prev_derived="${DERIVED_DATA_PATH:-}"
    # shellcheck source=Scripts/ensure-simulator.sh
    source "$repo_root/Scripts/ensure-simulator.sh"
    if resolve_or_create_simulator >/dev/null 2>&1; then
      run_udid="$SIMULATOR_UDID"
    fi
    if [[ -n "$prev_name" ]]; then
      TRINKET_SIMULATOR_NAME="$prev_name"
    else
      unset TRINKET_SIMULATOR_NAME
    fi
    DERIVED_DATA_PATH="$prev_derived"
    export DERIVED_DATA_PATH
  fi
  if [[ -z "$run_udid" ]]; then
    echo "warning: auto-mirror could not resolve $run_name UDID" >&2
    return 0
  fi

  local run_state=""
  run_state="$(xcrun simctl list devices "$run_udid" -j 2>/dev/null | python3 "$repo_root/Scripts/simctl_json.py" state-for-udid "$run_udid" 2>/dev/null || echo "Unknown")"
  if [[ "$run_state" != "Booted" ]]; then
    echo "Auto-mirror: booting $run_name ($run_udid) for install..."
    if ! xcrun simctl boot "$run_udid" >/dev/null 2>&1; then
      echo "warning: auto-mirror could not boot $run_name" >&2
      return 0
    fi
    xcrun simctl bootstatus "$run_udid" -b >/dev/null 2>&1 || true
  fi

  echo "Auto-mirror: installing to $run_name ($run_udid)..."
  xcrun simctl terminate "$run_udid" "$bundle_id" 2>/dev/null || true
  if ! xcrun simctl install "$run_udid" "$src_app" 2>&1; then
    echo "warning: auto-mirror install to $run_name failed" >&2
    return 0
  fi
  echo "Auto-mirror: $run_name now matches isolated build ($bundle_id)."

  local agent_udid agent_name
  while IFS=$'\t' read -r agent_udid agent_name; do
    [[ -n "$agent_udid" ]] || continue
    [[ "$agent_udid" == "$run_udid" ]] && continue
    [[ "$agent_name" == Trinket\ Agent* ]] || continue
    echo "Auto-mirror: also updating $agent_name ($agent_udid)..."
    xcrun simctl terminate "$agent_udid" "$bundle_id" 2>/dev/null || true
    xcrun simctl install "$agent_udid" "$src_app" 2>/dev/null || true
  done < <(xcrun simctl list devices available -j 2>/dev/null | python3 "$repo_root/Scripts/simctl_json.py" booted-managed 2>/dev/null || true)

  if [[ "${TRINKET_HANDOFF_AUTO_LAUNCH:-0}" == "1" ]]; then
    local sim_app_running=""
    sim_app_running="$(pgrep -x Simulator 2>/dev/null || true)"
    if [[ -n "$sim_app_running" ]]; then
      echo "Auto-mirror: launching $bundle_id on $run_name..."
      xcrun simctl launch --terminate-running-process "$run_udid" "$bundle_id" -- -appearance dark 2>/dev/null || true
    fi
  fi
  return 0
}
