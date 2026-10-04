#!/usr/bin/env bash

trinket_simctl_json() {
  python3 "$(trinket_run_env_repo_root)/Scripts/simctl_json.py" "$@"
}

# Single source for managed simulator names; fall back to checked-in defaults
# when this file is copied standalone into a fixture repo without config/.
_trinket_simctl_config=""
_trinket_simctl_config_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../config" 2>/dev/null && pwd || true)"
if [[ -n "$_trinket_simctl_config_dir" ]]; then
  _trinket_simctl_config="$_trinket_simctl_config_dir/simulator-names.env"
fi
# shellcheck source=../config/simulator-names.env
if [[ -n "$_trinket_simctl_config" && -f "$_trinket_simctl_config" ]]; then
  source "$_trinket_simctl_config"
else
  TRINKET_SHARED_SIM_NAMES=("Trinket Run" "Trinket CI")
  TRINKET_AGENT_SIM_PATTERN='^Trinket Agent [0-9]+$'
fi
unset _trinket_simctl_config _trinket_simctl_config_dir

trinket_simulator_is_shared_name() {
  local name="$1"
  local candidate
  for candidate in "${TRINKET_SHARED_SIM_NAMES[@]}"; do
    [[ "$name" == "$candidate" ]] && return 0
  done
  return 1
}

trinket_watch_agent_simulator() {
  [[ "${TRINKET_ISOLATE:-}" == "1" && -n "${TRINKET_SIM_SLOT_PATH:-}" && -n "${TRINKET_SIM_SLOT_OWNER_PID:-}" && -n "${SIMULATOR_UDID:-}" ]] || return 0
  python3 "$(trinket_run_env_repo_root)/Scripts/agent-sim-lifetime.py" register \
    --slot "$TRINKET_SIM_SLOT_PATH" --owner "${TRINKET_SIM_SLOT_OWNER_PID%%:*}" --udid "$SIMULATOR_UDID" \
    --name "$SIMULATOR_NAME" --grace "${TRINKET_AGENT_SIM_IDLE_SECONDS:-60}"
}

trinket_simulator_is_active_agent_name() {
  local name="$1"
  [[ "$name" =~ ^Trinket\ Agent\ ([0-9]+)$ ]] \
    && [[ -e "${TRINKET_SIM_ACTIVE_DIR:-$(trinket_run_env_shared_root)/.active-sim}/${BASH_REMATCH[1]}.slot" ]]
}

trinket_simulator_is_leased_name() {
  trinket_simulator_is_active_agent_name "$1" || {
    trinket_simulator_is_shared_name "$1" \
      && [[ -e "${TRINKET_SIM_ACTIVE_DIR:-$(trinket_run_env_shared_root)/.active-sim}/run.slot" ]]
  }
}

# XCTest agents belong to launchd_sim, outside xcodebuild's host process tree.
# Record the pre-run guests so lease cleanup never stops a pre-existing test.
trinket_test_guest_processes() {
  local processes
  processes="$(ps -axo pid=,ppid=,lstart=,command=)" || return 1
  printf '%s\n' "$processes" | awk -v udid="$1" '
    $8 == "launchd_sim" && index($0, "/Devices/" udid "/data/var/run/launchd_bootstrap.plist") { guests[$1] = 1 }
    $8 ~ /\/Agents\/xctest$|\/TrinketUITests-Runner\.app\/TrinketUITests-Runner$/ {
      identity[NR] = $1 " " $2 " " $3 " " $4 " " $5 " " $6 " " $7; parent[NR] = $2
    }
    END { for (row in identity) if (parent[row] in guests) print identity[row] }
  ' | LC_ALL=C sort
}

trinket_test_guest_cleanup_file() {
  local record="$1" owner udid identity pid current
  [[ -f "$record" ]] || return 0
  read -r owner udid < "$record" || return 1
  current="$(trinket_test_guest_processes "$udid")" || return 1
  while IFS= read -r identity; do
    [[ -n "$identity" ]] || continue
    grep -Fxq -- "$identity" "$record" && continue
    pid="${identity%% *}"
    echo "Stopping leftover XCTest process $pid on leased simulator $udid." >&2
    # A suspended launch cannot handle TERM. These are surviving guests after
    # the owning run ended; identity includes start time to avoid PID reuse.
    trinket_test_guest_processes "$udid" | grep -Fxq -- "$identity" || continue
    kill -KILL "$pid" 2>/dev/null || true
  done <<< "$current"
  rm -f "$record"
}

trinket_track_test_guests_locked() {
  local record="$1" owner="$2" prior_owner prior_udid current
  if [[ -f "$record" ]]; then
    read -r prior_owner prior_udid < "$record" || return 1
    [[ "$prior_owner" =~ ^[0-9]+$ && -n "$prior_udid" ]] || return 1
    if [[ "$prior_owner" == "$owner" && "$prior_udid" == "$SIMULATOR_UDID" ]]; then
      return 0
    fi
    # Recover a killed runner only after its recorded lease owner is dead.
    if [[ "$prior_owner" != "$owner" ]] && ! trinket_lock_pid_is_stale "$prior_owner"; then
      return 1
    fi
    # A recreated device can reuse the slot, but its old UDID is no longer ours.
    if [[ "$prior_udid" == "$SIMULATOR_UDID" ]]; then
      trinket_test_guest_cleanup_file "$record" || return 1
    else
      rm -f "$record" || return 1
    fi
  fi
  # Never publish an empty baseline after a failed process query.
  current="$(trinket_test_guest_processes "$SIMULATOR_UDID")" || return 1
  { printf '%s %s\n' "$owner" "$SIMULATOR_UDID"; [[ -z "$current" ]] || printf '%s\n' "$current"; } > "$record.tmp" || return 1
  mv "$record.tmp" "$record"
}

trinket_track_test_guests() {
  local lease="${TRINKET_SIM_SLOT_PATH:-${TRINKET_SHARED_SIM_SLOT_PATH:-}}"
  local owner record status=0
  [[ -n "${SIMULATOR_UDID:-}" && -f "$lease" ]] || return 0
  read -r owner _ < "$lease" || return 1
  [[ "$owner" =~ ^[0-9]+$ ]] || return 1
  record="$lease.guest-tests"
  trinket_dir_lock_acquire "$record.lock" 5 || return 1
  trinket_track_test_guests_locked "$record" "$owner" || status=$?
  trinket_dir_lock_release "$record.lock" "${BASHPID:-$$}"
  return "$status"
}

trinket_cleanup_test_guests() {
  local lease owner record_owner
  for lease in "${TRINKET_SIM_SLOT_PATH:-}" "${TRINKET_SHARED_SIM_SLOT_PATH:-}"; do
    [[ -f "$lease" ]] || continue
    read -r owner _ < "$lease" || continue
    [[ "$owner" == "${BASHPID:-$$}" ]] || continue
    [[ -f "$lease.guest-tests" ]] || continue
    read -r record_owner _ < "$lease.guest-tests" || continue
    [[ "$record_owner" == "$owner" ]] || continue
    trinket_test_guest_cleanup_file "$lease.guest-tests" || true
  done
}

trinket_sim_shutdown_wait() {
  local udid="$1"
  local device_set="${2:-}"
  local timeout_seconds="${TRINKET_SIMULATOR_SHUTDOWN_TIMEOUT_SECONDS:-45}"

  if [[ -n "$udid" && "$udid" != "all" ]]; then
    if [[ -n "$device_set" ]]; then
      xcrun simctl $device_set spawn "$udid" launchctl stop com.apple.PosterBoard >/dev/null 2>&1 || true
      xcrun simctl $device_set shutdown "$udid" >/dev/null 2>&1 || true
    else
      xcrun simctl spawn "$udid" launchctl stop com.apple.PosterBoard >/dev/null 2>&1 || true
      xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
    fi
  elif [[ "$udid" == "all" ]]; then
    if [[ -n "$device_set" ]]; then
      xcrun simctl $device_set shutdown all >/dev/null 2>&1 || true
    else
      xcrun simctl shutdown all >/dev/null 2>&1 || true
    fi
  fi

  [[ "$timeout_seconds" =~ ^[0-9]+$ ]] || timeout_seconds=45
  (( timeout_seconds > 0 )) || return 0

  local deadline=$((SECONDS + timeout_seconds))
  while (( SECONDS < deadline )); do
    local state=""
    if [[ -n "$udid" && "$udid" != "all" ]]; then
      local sim_cmd=("xcrun" "simctl")
      [[ -n "$device_set" ]] && sim_cmd+=($device_set)
      sim_cmd+=("list" "devices" "$udid" "-j")
      state="$("${sim_cmd[@]}" 2>/dev/null | trinket_simctl_json state-for-udid "${udid}" 2>/dev/null || true)"
      if [[ "$state" == "Shutdown" || -z "$state" ]]; then
        return 0
      fi
    else
      local sim_cmd=("xcrun" "simctl")
      [[ -n "$device_set" ]] && sim_cmd+=($device_set)
      sim_cmd+=("list" "devices" "available" "-j")
      local booted_count=0
      booted_count="$("${sim_cmd[@]}" 2>/dev/null | trinket_simctl_json count-booted 2>/dev/null || echo 0)"
      if (( booted_count == 0 )); then
        return 0
      fi
    fi
    sleep 0.25
  done
  echo "warning: simulator did not reach Shutdown within ${timeout_seconds}s (udid: $udid)" >&2
}

trinket_preview_sims_reclaim() {
  local default_cleanup="0"
  if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
    default_cleanup="1"
  fi
  local enabled="${TRINKET_CLEANUP_PREVIEW_SIMS:-$default_cleanup}"
  [[ "$enabled" == "1" ]] || return 0

  local previews_root="${HOME}/Library/Developer/Xcode/UserData/Previews"
  local dir
  for dir in \
    "${previews_root}/Simulator Devices" \
    "${previews_root}/Simulator%20Devices"
  do
    [[ -d "$dir" ]] || continue
    find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + >/dev/null 2>&1 || true
  done

  local preview_counts=""
  if preview_counts="$(
    xcrun simctl --set previews list devices available -j 2>/dev/null \
      | sed -n '/^{/,$p' \
      | trinket_simctl_json preview-count 2>/dev/null
  )"; then
    :
  else
    preview_counts="0	0"
  fi

  local preview_total=0
  local preview_booted=0
  IFS=$'\t' read -r preview_total preview_booted <<< "$preview_counts" || true
  [[ "$preview_total" =~ ^[0-9]+$ ]] || preview_total=0
  [[ "$preview_booted" =~ ^[0-9]+$ ]] || preview_booted=0

  if (( preview_total > 0 )); then
    echo "Simulator cleanup: reclaiming Xcode Preview devices (${preview_total} device(s), ${preview_booted} Booted)."
    if (( preview_booted > 0 )); then
      trinket_sim_shutdown_wait "all" "--set previews"
    fi
    xcrun simctl --set previews delete all >/dev/null 2>&1 || true
  fi
}

trinket_sim_cleanup_lock_try_acquire() {
  local shared_root="$1"
  local lock_path="$shared_root/.simulator-cleanup.lock"
  local lock_pid=""
  mkdir -p "$shared_root"

  if [[ -e "$lock_path" ]]; then
    read -r lock_pid _ < "$lock_path" || true
    # Deliberately fail-open (unlike trinket_lock_pid_is_stale): an
    # unparseable pid here means hygiene already lost track of its owner,
    # so reclaim the cleanup lock instead of stalling simulator hygiene.
    if [[ ! "$lock_pid" =~ ^[0-9]+$ ]] || ! kill -0 "$lock_pid" 2>/dev/null; then
      rm -f "$lock_path"
    else
      return 1
    fi
  fi

  if ! trinket_lock_claim_file "$lock_path" "$$ ${TRINKET_RUN_ID:-shared}"; then
    return 1
  fi
  return 0
}

trinket_sim_cleanup_lock_release() {
  rm -f "$1/.simulator-cleanup.lock"
}

trinket_simulator_enforce_single_warm_booted() {
  [[ "${TRINKET_CLEANUP_SINGLE_WARMED:-1}" == "1" ]] || return 0

  local shared_root="${TRINKET_SHARED_DERIVED_DATA:-$(trinket_run_env_shared_root)}"
  if ! trinket_sim_cleanup_lock_try_acquire "$shared_root"; then
    return 0
  fi

  local managed_devices=""
  if ! managed_devices="$(xcrun simctl list devices available -j 2>/dev/null | trinket_simctl_json booted-managed)"; then
    trinket_sim_cleanup_lock_release "$shared_root"
    return 0
  fi

  local -a managed_udids=()
  local -a managed_names=()
  local udid name
  while IFS=$'\t' read -r udid name; do
    [[ -n "$udid" ]] || continue
    managed_udids+=("$udid")
    managed_names+=("$name")
  done <<< "$managed_devices"

  local managed_count="${#managed_udids[@]}"
  if (( managed_count <= 1 )); then
    trinket_sim_cleanup_lock_release "$shared_root"
    return 0
  fi

  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    local keep_index=-1
    local index
    for index in "${!managed_names[@]}"; do
      if trinket_simulator_is_leased_name "${managed_names[$index]}"; then
        keep_index="$index"
        break
      fi
    done
    if (( keep_index < 0 )) && [[ -n "${TRINKET_SIMULATOR_NAME:-}" ]]; then
      for index in "${!managed_names[@]}"; do
        if [[ "${managed_names[$index]}" == "${TRINKET_SIMULATOR_NAME}" ]]; then
          keep_index="$index"
          break
        fi
      done
    fi
    if (( keep_index < 0 )); then
      for index in "${!managed_names[@]}"; do
        if trinket_simulator_is_shared_name "${managed_names[$index]}"; then
          keep_index="$index"
          break
        fi
      done
    fi
    if (( keep_index < 0 )); then
      keep_index=0
    fi

    echo "Simulator cleanup: keeping ${managed_names[$keep_index]} Booted; reclaiming unleased excess managed simulators."
    for index in "${!managed_udids[@]}"; do
      if (( index == keep_index )); then
        continue
      fi
      trinket_simulator_is_leased_name "${managed_names[$index]}" && continue
      trinket_sim_shutdown_wait "${managed_udids[$index]}"
    done

    trinket_sim_cleanup_lock_release "$shared_root"
    return 0
  fi

  local -a agent_udids=()
  local -a agent_names=()
  local -a run_udids=()
  local -a run_names=()
  for index in "${!managed_names[@]}"; do
    udid="${managed_udids[$index]}"
    name="${managed_names[$index]}"
    if [[ "$name" =~ $TRINKET_AGENT_SIM_PATTERN ]]; then
      agent_udids+=("$udid")
      agent_names+=("$name")
    elif trinket_simulator_is_shared_name "$name"; then
      run_udids+=("$udid")
      run_names+=("$name")
    else
      agent_udids+=("$udid")
      agent_names+=("$name")
    fi
  done

  local agent_count="${#agent_udids[@]}"
  local run_count="${#run_udids[@]}"

  if (( agent_count > 1 )); then
    local keep_agent=-1
    for index in "${!agent_names[@]}"; do
      if trinket_simulator_is_active_agent_name "${agent_names[$index]}"; then
        keep_agent="$index"
        break
      fi
    done
    if (( keep_agent < 0 )) && [[ -n "${TRINKET_SIMULATOR_NAME:-}" ]]; then
      for index in "${!agent_names[@]}"; do
        if [[ "${agent_names[$index]}" == "${TRINKET_SIMULATOR_NAME}" ]]; then
          keep_agent="$index"
          break
        fi
      done
    fi
    if (( keep_agent < 0 )); then
      keep_agent=0
    fi
    echo "Simulator cleanup: keeping ${agent_names[$keep_agent]} Booted; reclaiming unleased excess agent simulators."
    for index in "${!agent_udids[@]}"; do
      if (( index == keep_agent )); then
        continue
      fi
      trinket_simulator_is_leased_name "${agent_names[$index]}" && continue
      trinket_sim_shutdown_wait "${agent_udids[$index]}"
    done
  fi

  if (( run_count > 1 )); then
    local keep_run=-1
    for index in "${!run_names[@]}"; do
      if [[ "${run_names[$index]}" == "Trinket Run" ]]; then
        keep_run="$index"
        break
      fi
    done
    if (( keep_run < 0 )) && [[ -n "${TRINKET_SIMULATOR_NAME:-}" ]]; then
      for index in "${!run_names[@]}"; do
        if [[ "${run_names[$index]}" == "${TRINKET_SIMULATOR_NAME}" ]]; then
          keep_run="$index"
          break
        fi
      done
    fi
    if (( keep_run < 0 )); then
      keep_run=0
    fi
    echo "Simulator cleanup: keeping ${run_names[$keep_run]} Booted; reclaiming unleased excess Trinket Run simulators."
    for index in "${!run_udids[@]}"; do
      if (( index == keep_run )); then
        continue
      fi
      trinket_simulator_is_leased_name "${run_names[$index]}" && continue
      trinket_sim_shutdown_wait "${run_udids[$index]}"
    done
  fi

  trinket_sim_cleanup_lock_release "$shared_root"
}
