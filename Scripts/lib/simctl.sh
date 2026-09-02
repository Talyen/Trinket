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

trinket_simulator_is_managed_name() {
  local name="$1"
  trinket_simulator_is_shared_name "$name" || [[ "$name" =~ $TRINKET_AGENT_SIM_PATTERN ]]
}

trinket_simulator_is_active_agent_name() {
  local name="$1"
  [[ "$name" =~ ^Trinket\ Agent\ ([0-9]+)$ ]] \
    && [[ -e "${TRINKET_SIM_ACTIVE_DIR:-$(trinket_run_env_shared_root)/.active-sim}/${BASH_REMATCH[1]}.slot" ]]
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
      if trinket_simulator_is_active_agent_name "${managed_names[$index]}"; then
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

    echo "Simulator cleanup: keeping ${managed_names[$keep_index]} Booted; shutting down $((managed_count - 1)) excess managed simulator(s)."
    for index in "${!managed_udids[@]}"; do
      if (( index == keep_index )); then
        continue
      fi
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
    echo "Simulator cleanup: keeping ${agent_names[$keep_agent]} Booted; shutting down $((agent_count - 1)) excess agent simulator(s)."
    for index in "${!agent_udids[@]}"; do
      if (( index == keep_agent )); then
        continue
      fi
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
    echo "Simulator cleanup: keeping ${run_names[$keep_run]} Booted; shutting down $((run_count - 1)) excess Trinket Run simulator(s)."
    for index in "${!run_udids[@]}"; do
      if (( index == keep_run )); then
        continue
      fi
      trinket_sim_shutdown_wait "${run_udids[$index]}"
    done
  fi

  trinket_sim_cleanup_lock_release "$shared_root"
}
