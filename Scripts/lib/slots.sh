#!/usr/bin/env bash

trinket_slot_owner_token() {
  printf '%s' "${BASHPID:-$$}:${BASH_SUBSHELL:-0}"
}

trinket_lock_claim_file() {
  ( set -o noclobber; printf '%s\n' "$2" > "$1" ) 2>/dev/null
}

trinket_slot_entry_is_stale() {
  local slot="$1"
  local pid="" stamp="" epoch="" now
  read -r pid _ stamp < "$slot" 2>/dev/null || true
  if [[ "$pid" =~ ^[0-9]+$ ]] && ! kill -0 "$pid" 2>/dev/null; then
    return 0
  fi
  local cap="${TRINKET_SLOT_STALE_SECONDS:-21600}"
  [[ "$cap" =~ ^[0-9]+$ ]] && (( cap > 0 )) || return 1
  [[ -n "$stamp" ]] || return 1
  epoch="$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$stamp" +%s 2>/dev/null || true)"
  [[ -n "$epoch" ]] || return 1
  now="$(date -u +%s)"
  (( now - epoch >= cap ))
}

trinket_slot_reap_dir() {
  local active_dir="$1"
  [[ -d "$active_dir" ]] || return 0
  local slot
  for slot in "$active_dir"/*.slot; do
    [[ -e "$slot" ]] || continue
    if trinket_slot_entry_is_stale "$slot"; then
      rm -f "$slot"
    fi
  done
}

trinket_sim_slot_reap() {
  trinket_slot_reap_dir "${TRINKET_SIM_ACTIVE_DIR:-$(trinket_run_env_shared_root)/.active-sim}"
}

trinket_ui_slot_reap() {
  trinket_slot_reap_dir "${TRINKET_UI_ACTIVE_DIR:-$(trinket_run_env_shared_root)/.active-ui}"
}

trinket_ui_slot_count() {
  local active_dir="${TRINKET_UI_ACTIVE_DIR:-$(trinket_run_env_shared_root)/.active-ui}"
  local count=0
  local slot
  [[ -d "$active_dir" ]] || { printf '0'; return; }
  for slot in "$active_dir"/*.slot; do
    [[ -e "$slot" ]] || continue
    count=$((count + 1))
  done
  printf '%s' "$count"
}

trinket_release_owned_slot() {
  local path="$1"
  local owner="$2"
  local current_owner
  current_owner="$(trinket_slot_owner_token)"
  if [[ -n "$path" && "$owner" == "$current_owner" && -e "$path" ]]; then
    rm -f "$path"
  fi
}

trinket_sim_slot_release() {
  trinket_release_owned_slot "${TRINKET_SIM_SLOT_PATH:-}" "${TRINKET_SIM_SLOT_OWNER_PID:-}"
  TRINKET_SIM_SLOT_PATH=""
  TRINKET_SIM_SLOT_OWNER_PID=""
}

trinket_ui_slot_release() {
  trinket_release_owned_slot "${TRINKET_UI_SLOT_PATH:-}" "${TRINKET_UI_SLOT_OWNER_PID:-}"
  TRINKET_UI_SLOT_PATH=""
  TRINKET_UI_SLOT_OWNER_PID=""
}

trinket_sim_slot_pool_is_empty() {
  local active_dir="${TRINKET_SIM_ACTIVE_DIR:-$(trinket_run_env_shared_root)/.active-sim}"
  local slot
  trinket_sim_slot_reap
  [[ -d "$active_dir" ]] || return 0
  for slot in "$active_dir"/*.slot; do
    [[ -e "$slot" ]] || continue
    return 1
  done
  return 0
}

trinket_shared_sim_lease_release() {
  if [[ -n "${TRINKET_SHARED_SIM_SLOT_PATH:-}" && -e "${TRINKET_SHARED_SIM_SLOT_PATH}" ]]; then
    local pid=""
    read -r pid _ < "${TRINKET_SHARED_SIM_SLOT_PATH}" 2>/dev/null || true
    if [[ "$pid" == "$$" ]] || trinket_slot_entry_is_stale "${TRINKET_SHARED_SIM_SLOT_PATH}"; then
      rm -f "${TRINKET_SHARED_SIM_SLOT_PATH}"
    fi
  fi
  TRINKET_SHARED_SIM_SLOT_PATH=""
}

trinket_bind_agent_slot() {
  local n="$1"
  local shared
  shared="$(trinket_run_env_shared_root)"
  TRINKET_AGENT_SLOT="$n"
  if [[ -z "${TRINKET_SIMULATOR_NAME:-}" ]]; then
    TRINKET_SIMULATOR_NAME="Trinket Agent $n"
  fi
  if [[ -z "${DERIVED_DATA_PATH:-}" ]]; then
    DERIVED_DATA_PATH="$shared/runs/agent-$n"
  fi
}

trinket_sim_slot_acquire() {
  local max="${TRINKET_MAX_AGENT_SIMS:-1}"
  local active_dir="${TRINKET_SIM_ACTIVE_DIR:-$(trinket_run_env_shared_root)/.active-sim}"
  local n slot_path owner_pid owner_token
  owner_pid="$$"
  owner_token="$(trinket_slot_owner_token)"
  mkdir -p "$active_dir"
  trinket_sim_slot_reap

  if [[ -n "${TRINKET_AGENT_SLOT:-}" && -n "${TRINKET_SIM_SLOT_PATH:-}" && -e "${TRINKET_SIM_SLOT_PATH}" ]]; then
    trinket_bind_agent_slot "$TRINKET_AGENT_SLOT"
    return 0
  fi

  for (( n = 1; n <= max; n++ )); do
    slot_path="$active_dir/$n.slot"
    if [[ -e "$slot_path" ]]; then
      continue
    fi
    if trinket_lock_claim_file "$slot_path" "$owner_pid ${TRINKET_RUN_ID:-shared} $(date -u +%Y-%m-%dT%H:%M:%SZ)"; then
      TRINKET_SIM_SLOT_PATH="$slot_path"
      TRINKET_SIM_SLOT_OWNER_PID="$owner_token"
      export TRINKET_SIM_SLOT_PATH
      export TRINKET_SIM_SLOT_OWNER_PID
      trinket_bind_agent_slot "$n"
      trinket_run_env_install_release_trap
      return 0
    fi
  done

  echo "Agent simulator slot pool full (0/$max free; TRINKET_MAX_AGENT_SIMS=$max)." >&2
  echo "Another agent or local isolated run is using a Trinket Agent simulator." >&2
  echo "Do not kill foreign xcodebuild/simctl processes." >&2
  echo "Options: retry after a peer finishes, use a git worktree (./Scripts/agent-worktree.sh), or raise TRINKET_MAX_AGENT_SIMS only with measured headroom." >&2
  return 1
}

trinket_sim_slot_ensure() {
  [[ "${TRINKET_ISOLATE:-}" == "1" ]] || return 0
  if [[ -n "${TRINKET_AGENT_SLOT:-}" ]]; then
    trinket_bind_agent_slot "$TRINKET_AGENT_SLOT"
    return 0
  fi
  if [[ -n "${TRINKET_SIMULATOR_NAME:-}" && -n "${DERIVED_DATA_PATH:-}" ]]; then
    return 0
  fi
  trinket_sim_slot_acquire
}

trinket_shared_sim_lease_acquire() {
  local active_dir="${TRINKET_SIM_ACTIVE_DIR:-$(trinket_run_env_shared_root)/.active-sim}"
  local path="$active_dir/run.slot"
  mkdir -p "$active_dir"
  trinket_sim_slot_reap
  if [[ -e "$path" ]]; then
    echo "Trinket Run is busy: shared simulator lease held by another run." >&2
    echo "Options: wait for the peer to finish, use --isolate for an agent-slot run, or use a git worktree (./Scripts/agent-worktree.sh)." >&2
    return 1
  fi
  if ! trinket_lock_claim_file "$path" "$$ ${TRINKET_RUN_ID:-shared} $(date -u +%Y-%m-%dT%H:%M:%SZ)"; then
    echo "Trinket Run is busy: another run claimed the shared simulator lease." >&2
    echo "Options: wait for the peer to finish, use --isolate for an agent-slot run, or use a git worktree (./Scripts/agent-worktree.sh)." >&2
    return 1
  fi
  TRINKET_SHARED_SIM_SLOT_PATH="$path"
  export TRINKET_SHARED_SIM_SLOT_PATH
  trinket_run_env_install_release_trap
}

trinket_ui_slot_acquire() {
  local max="${TRINKET_MAX_CONCURRENT_UI:-2}"
  local active_dir="${TRINKET_UI_ACTIVE_DIR:-$(trinket_run_env_shared_root)/.active-ui}"
  local slot_name count lock_path lock_pid owner_pid owner_token
  owner_pid="$$"
  owner_token="$(trinket_slot_owner_token)"
  mkdir -p "$active_dir"
  trinket_ui_slot_reap

  lock_path="$active_dir/.acquire.lock"
  if [[ -e "$lock_path" ]]; then
    lock_pid=""
    read -r lock_pid _ < "$lock_path" || true
    if [[ "$lock_pid" =~ ^[0-9]+$ ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
      rm -f "$lock_path"
    fi
  fi
  if ! trinket_lock_claim_file "$lock_path" "$owner_pid ${TRINKET_RUN_ID:-shared}"; then
    echo "UI/smoke concurrency reservation is busy; retry after the peer finishes." >&2
    return 1
  fi

  count="$(trinket_ui_slot_count)"
  if (( count >= max )); then
    rm -f "$lock_path"
    echo "UI/smoke concurrency cap reached ($count/$max active)." >&2
    echo "Another agent or local run is using the simulator lane." >&2
    echo "Do not kill foreign xcodebuild/simctl processes." >&2
    echo "Options: retry after a peer finishes, use a git worktree (./Scripts/agent-worktree.sh), or raise TRINKET_MAX_CONCURRENT_UI only with measured headroom." >&2
    return 1
  fi

  slot_name="${TRINKET_RUN_ID:-shared}-$owner_pid-${RANDOM:-0}-$(date -u +%Y%m%dT%H%M%SZ).slot"
  TRINKET_UI_SLOT_PATH="$active_dir/$slot_name"
  if ! printf '%s %s %s\n' "$owner_pid" "${TRINKET_RUN_ID:-shared}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$TRINKET_UI_SLOT_PATH"; then
    rm -f "$lock_path"
    return 1
  fi
  export TRINKET_UI_SLOT_PATH
  TRINKET_UI_SLOT_OWNER_PID="$owner_token"
  export TRINKET_UI_SLOT_OWNER_PID
  rm -f "$lock_path"
  trinket_run_env_install_release_trap
}
