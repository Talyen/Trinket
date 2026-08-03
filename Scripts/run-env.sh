#!/usr/bin/env bash
# Shared run-tenant setup for build/test wrappers.
#
# Source this file, then call trinket_run_env_init once near script start.
# Default (no isolate): $PWD/.DerivedData + simulator "Trinket CI".
# Isolated (TRINKET_ISOLATE=1): acquires a reusable agent simulator slot
# (Trinket Agent N) with DerivedData under .DerivedData/runs/agent-N/.
#
# On self-clean start + EXIT (top-level owner only): reclaim Preview sims, enforce
# exactly one Booted managed sim (Agent or CI), and age-prune bulky artifacts.
# The keep-target stays Booted (no routine shutdown/erase — avoids CrashReporter
# sheets from guest apps). Nested children release leases only.
#
# Generation lock and XcodeGen cache stay under the shared $PWD/.DerivedData root
# because they mutate the repo project tree, not build products.

trinket_run_env_repo_root() {
  if [[ -n "${TRINKET_REPO_ROOT:-}" ]]; then
    printf '%s' "$TRINKET_REPO_ROOT"
    return
  fi
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  printf '%s' "$here"
}

trinket_run_env_shared_root() {
  printf '%s/.DerivedData' "$(trinket_run_env_repo_root)"
}

trinket_simulator_is_managed_name() {
  local name="$1"
  [[ "$name" == "Trinket CI" || "$name" =~ ^Trinket\ Agent\ [0-9]+$ ]]
}

trinket_simulator_is_active_agent_name() {
  local name="$1"
  [[ "$name" =~ ^Trinket\ Agent\ ([0-9]+)$ ]] \
    && [[ -e "${TRINKET_SIM_ACTIVE_DIR:-$(trinket_run_env_shared_root)/.active-sim}/${BASH_REMATCH[1]}.slot" ]]
}

# Shut down + delete Xcode Preview simulator devices (best-effort), then prune
# leftover device dirs under both literal and URL-encoded Previews paths.
trinket_preview_sims_reclaim() {
  [[ "${TRINKET_CLEANUP_PREVIEW_SIMS:-1}" == "1" ]] || return 0
  echo "Simulator cleanup: reclaiming Xcode Preview devices."
  xcrun simctl --set previews shutdown all >/dev/null 2>&1 || true
  xcrun simctl --set previews delete all >/dev/null 2>&1 || true
  local previews_root="${HOME}/Library/Developer/Xcode/UserData/Previews"
  local dir
  for dir in \
    "${previews_root}/Simulator Devices" \
    "${previews_root}/Simulator%20Devices"
  do
    [[ -d "$dir" ]] || continue
    find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + >/dev/null 2>&1 || true
  done
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

# Age-prune bulky rebuildable artifacts under the shared .DerivedData root and
# package-local build trees. Keeps warm runs/agent-N Build products; never wipes
# Intermediates by default. Does not touch ~/Library/Developer/Xcode/DerivedData.
trinket_derived_data_age_prune() {
  [[ "${TRINKET_CLEANUP_DERIVED_DATA_AGE_PRUNE:-1}" == "1" ]] || return 0
  local shared_root="${TRINKET_SHARED_DERIVED_DATA:-$(trinket_run_env_shared_root)}"
  local max_age_days="${TRINKET_RUN_MAX_AGE_DAYS:-3}"
  local artifact_age_days="${TRINKET_ARTIFACT_MAX_AGE_DAYS:-${max_age_days}}"
  local repo_root
  repo_root="$(trinket_run_env_repo_root)"

  if [[ -d "$shared_root" ]]; then
    # One-off isolated runs (not reusable agent-N tenants).
    if [[ -d "$shared_root/runs" ]]; then
      find "$shared_root/runs" -mindepth 1 -maxdepth 1 -type d \
        ! -name 'agent-*' \
        -mtime "+${max_age_days}" \
        -exec rm -rf {} + 2>/dev/null || true
    fi

    # Bulky result trees under the shared root and each agent tenant.
    local -a roots=("$shared_root")
    local agent_dir
    if [[ -d "$shared_root/runs" ]]; then
      for agent_dir in "$shared_root/runs"/agent-*; do
        [[ -d "$agent_dir" ]] || continue
        roots+=("$agent_dir")
      done
    fi
    local root name
    for root in "${roots[@]}"; do
      for name in TestResults PerformanceResults Logs; do
        if [[ -d "$root/$name" ]]; then
          find "$root/$name" -mindepth 1 -maxdepth 1 -mtime "+${artifact_age_days}" \
            -exec rm -rf {} + 2>/dev/null || true
        fi
      done
    done
  fi

  # Package-local SPM / Xcode package caches (gitignored).
  local package_dir
  if [[ -d "$repo_root/Packages" ]]; then
    for package_dir in "$repo_root/Packages"/*; do
      [[ -d "$package_dir" ]] || continue
      for name in .build .DerivedData; do
        if [[ -d "$package_dir/$name" ]]; then
          find "$package_dir/$name" -mindepth 0 -maxdepth 0 -mtime "+${artifact_age_days}" \
            -exec rm -rf {} + 2>/dev/null || true
        fi
      done
    done
  fi
}

# Opt-in escape hatch only (TRINKET_CLEANUP_IDLE_POOL=1): when isolate + no agent
# sim slots held, shut down Booted Trinket Agent N devices, then erase Agent
# device data (keeps entries). Default off — normal hygiene never erases. Never
# touches shared Trinket CI. Peers with held slots are untouched.
trinket_simulator_cleanup_idle_pool() {
  [[ "${TRINKET_CLEANUP_IDLE_POOL:-0}" == "1" ]] || return 0
  # Shared warm-cache path must not reclaim agents; only isolate tenants do.
  [[ "${TRINKET_ISOLATE:-}" == "1" ]] || return 0

  local shared_root="${TRINKET_SHARED_DERIVED_DATA:-$(trinket_run_env_shared_root)}"
  local lock_path="$shared_root/.simulator-cleanup.lock"
  mkdir -p "$shared_root"

  if [[ -e "$lock_path" ]]; then
    local lock_pid=""
    read -r lock_pid _ < "$lock_path" || true
    if [[ "$lock_pid" =~ ^[0-9]+$ ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
      rm -f "$lock_path"
    else
      echo "Simulator cleanup already owned by pid ${lock_pid:-unknown}; leaving managed simulators running." >&2
      return 0
    fi
  fi

  if ! (set -o noclobber; printf '%s %s\n' "$$" "${TRINKET_RUN_ID:-shared}" > "$lock_path") 2>/dev/null; then
    echo "Simulator cleanup reservation is busy; leaving managed simulators running." >&2
    return 0
  fi

  if ! trinket_sim_slot_pool_is_empty; then
    echo "Simulator cleanup: agent sim pool still held; leaving managed simulators running."
    rm -f "$lock_path"
    return 0
  fi

  local managed_devices=""
  if ! managed_devices="$(xcrun simctl list devices available -j 2>/dev/null | python3 -c '
import json
import re
import sys

payload = json.load(sys.stdin)
records = []
for runtime_identifier, devices in payload.get("devices", {}).items():
    for device in devices:
        name = device.get("name", "")
        # Agents only — shared Trinket CI stays warm for non-isolate humans/CI.
        if re.fullmatch(r"Trinket Agent \d+", name):
            udid = device.get("udid", "")
            state = device.get("state", "")
            if udid:
                records.append((name, udid, state, runtime_identifier))

for name, udid, state, runtime_identifier in records:
    print(f"{udid}\t{name}\t{state}\t{runtime_identifier}")
')"; then
    echo "Unable to list managed simulators; leaving them running." >&2
    rm -f "$lock_path"
    return 0
  fi

  local -a managed_udids=()
  local -a managed_names=()
  local -a managed_states=()
  local udid name state runtime
  while IFS=$'\t' read -r udid name state runtime; do
    [[ -n "$udid" ]] || continue
    managed_udids+=("$udid")
    managed_names+=("$name")
    managed_states+=("$state")
  done <<< "$managed_devices"

  if (( ${#managed_udids[@]} == 0 )); then
    rm -f "$lock_path"
    return 0
  fi

  local index
  for index in "${!managed_udids[@]}"; do
    if [[ "${managed_states[$index]}" == "Booted" ]]; then
      xcrun simctl shutdown "${managed_udids[$index]}" >/dev/null 2>&1 || true
    fi
  done

  for index in "${!managed_udids[@]}"; do
    xcrun simctl erase "${managed_udids[$index]}" >/dev/null 2>&1 || true
  done

  rm -f "$lock_path"
}

# Keep exactly one Booted managed sim (Trinket CI / Trinket Agent N). Quietly
# shut down the rest; never erase. Default on for self-clean start + EXIT.
trinket_simulator_enforce_single_warm_booted() {
  [[ "${TRINKET_CLEANUP_SINGLE_WARMED:-1}" == "1" ]] || return 0

  local shared_root="${TRINKET_SHARED_DERIVED_DATA:-$(trinket_run_env_shared_root)}"
  local lock_path="$shared_root/.simulator-cleanup.lock"
  mkdir -p "$shared_root"

  if [[ -e "$lock_path" ]]; then
    local lock_pid=""
    read -r lock_pid _ < "$lock_path" || true
    if [[ "$lock_pid" =~ ^[0-9]+$ ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
      rm -f "$lock_path"
    else
      return 0
    fi
  fi

  if ! (set -o noclobber; printf '%s %s\n' "$$" "${TRINKET_RUN_ID:-shared}" > "$lock_path") 2>/dev/null; then
    return 0
  fi

  local managed_devices=""
  if ! managed_devices="$(xcrun simctl list devices available -j 2>/dev/null | python3 -c '
import json
import re
import sys

payload = json.load(sys.stdin)
records = []
for runtime_identifier, devices in payload.get("devices", {}).items():
    for device in devices:
        name = device.get("name", "")
        if device.get("state") != "Booted":
            continue
        if name == "Trinket CI" or re.fullmatch(r"Trinket Agent \d+", name):
            udid = device.get("udid", "")
            if udid:
                records.append((name, udid, runtime_identifier))

for name, udid, runtime_identifier in records:
    print(f"{udid}\t{name}\t{runtime_identifier}")
')"; then
    rm -f "$lock_path"
    return 0
  fi

  local -a managed_udids=()
  local -a managed_names=()
  local udid name runtime
  while IFS=$'\t' read -r udid name runtime; do
    [[ -n "$udid" ]] || continue
    managed_udids+=("$udid")
    managed_names+=("$name")
  done <<< "$managed_devices"

  local managed_count="${#managed_udids[@]}"
  if (( managed_count <= 1 )); then
    rm -f "$lock_path"
    return 0
  fi

  # Prefer: held agent slot → TRINKET_SIMULATOR_NAME → Trinket CI → first.
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
      if [[ "${managed_names[$index]}" == "Trinket CI" ]]; then
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
    xcrun simctl shutdown "${managed_udids[$index]}" >/dev/null 2>&1 || true
  done

  rm -f "$lock_path"
}

# Legacy alias: TRINKET_CLEANUP_EXCESS_SIMULATORS=1 maps to single-warm enforcement.
trinket_simulator_cleanup_excess() {
  [[ "${TRINKET_CLEANUP_EXCESS_SIMULATORS:-0}" == "1" ]] || return 0
  TRINKET_CLEANUP_SINGLE_WARMED=1 trinket_simulator_enforce_single_warm_booted
}

# Preview reclaim + single-warm + age-prune. Used on self-clean start and EXIT.
trinket_run_env_self_clean_hygiene() {
  trinket_preview_sims_reclaim
  trinket_simulator_enforce_single_warm_booted
  trinket_simulator_cleanup_idle_pool
  trinket_derived_data_age_prune
  trinket_simulator_cleanup_excess
}

# Claim once per process tree. Nested children inherit the parent token and must
# not overwrite it — otherwise every child EXIT would wipe Previews mid-plan.
trinket_run_env_claim_self_clean_owner() {
  if [[ -z "${TRINKET_SELF_CLEAN_OWNER:-}" ]]; then
    TRINKET_SELF_CLEAN_OWNER="${BASHPID:-$$}:${BASH_SUBSHELL:-0}"
    export TRINKET_SELF_CLEAN_OWNER
  fi
}

trinket_run_env_release_slots() {
  trinket_sim_slot_release
  trinket_ui_slot_release
  # Self-clean only for the top-level owner (verify/test parent). Children that
  # inherit the trap still release their own leases, but skip Preview / single-
  # warm / age-prune so a mid-plan child EXIT cannot disrupt peers or Xcode Previews.
  local current_owner="${BASHPID:-$$}:${BASH_SUBSHELL:-0}"
  if [[ "${TRINKET_SELF_CLEAN_OWNER:-}" == "$current_owner" ]]; then
    trinket_run_env_self_clean_hygiene
  fi
}

trinket_run_env_install_release_trap() {
  trap 'trinket_run_env_release_slots' EXIT INT TERM
}

# Top-level verify/test: claim self-clean, run start hygiene, install EXIT release.
trinket_run_env_install_self_clean() {
  trinket_run_env_claim_self_clean_owner
  local current_owner="${BASHPID:-$$}:${BASH_SUBSHELL:-0}"
  if [[ "${TRINKET_SELF_CLEAN_OWNER:-}" == "$current_owner" ]]; then
    trinket_run_env_self_clean_hygiene
  fi
  trinket_run_env_install_release_trap
}

# Legacy name used by test.sh / test-package.sh.
trinket_run_env_install_test_simulator_cleanup() {
  # Keep the older env var in sync for any external callers still checking it.
  trinket_run_env_claim_self_clean_owner
  TRINKET_TEST_SIMULATOR_CLEANUP_OWNER="${TRINKET_SELF_CLEAN_OWNER}"
  export TRINKET_TEST_SIMULATOR_CLEANUP_OWNER
  local current_owner="${BASHPID:-$$}:${BASH_SUBSHELL:-0}"
  if [[ "${TRINKET_SELF_CLEAN_OWNER:-}" == "$current_owner" ]]; then
    trinket_run_env_self_clean_hygiene
  fi
  trinket_run_env_install_release_trap
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

trinket_sim_slot_reap() {
  local active_dir="${TRINKET_SIM_ACTIVE_DIR:-$(trinket_run_env_shared_root)/.active-sim}"
  [[ -d "$active_dir" ]] || return 0
  local slot pid
  for slot in "$active_dir"/*.slot; do
    [[ -e "$slot" ]] || continue
    pid=""
    if [[ -f "$slot" ]]; then
      read -r pid _ < "$slot" || true
    fi
    if [[ "$pid" =~ ^[0-9]+$ ]] && ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$slot"
    fi
  done
}

trinket_sim_slot_release() {
  local current_owner="${BASHPID:-$$}:${BASH_SUBSHELL:-0}"
  # A child process inherits the parent's lease path.  Only the process that
  # claimed the lease may remove it; otherwise a UI child can release the
  # parent's simulator while the parent is still running.
  if [[ -n "${TRINKET_SIM_SLOT_PATH:-}" \
    && "${TRINKET_SIM_SLOT_OWNER_PID:-}" == "$current_owner" \
    && -e "${TRINKET_SIM_SLOT_PATH}" ]]; then
    rm -f "$TRINKET_SIM_SLOT_PATH"
  fi
  TRINKET_SIM_SLOT_PATH=""
  TRINKET_SIM_SLOT_OWNER_PID=""
}

# Agents stay warm after release (no routine shutdown/erase).
trinket_sim_slot_acquire() {
  local max="${TRINKET_MAX_AGENT_SIMS:-1}"
  local active_dir="${TRINKET_SIM_ACTIVE_DIR:-$(trinket_run_env_shared_root)/.active-sim}"
  local n slot_path owner_pid owner_token
  owner_pid="$$"
  # BASHPID is unavailable in macOS Bash 3.2; BASH_SUBSHELL distinguishes a
  # same-shell `( ... )` child while $$ distinguishes a new bash process.
  owner_token="${BASHPID:-$$}:${BASH_SUBSHELL:-0}"
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
    # Claim with noclobber to avoid two agents racing the same index.
    if ( set -o noclobber; printf '%s %s %s\n' "$owner_pid" "${TRINKET_RUN_ID:-shared}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$slot_path" ) 2>/dev/null; then
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

# Idempotent: acquire a sim slot when isolated and none is bound yet.
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

trinket_run_env_init() {
  local root shared
  local derived_explicit=0
  local sim_explicit=0
  root="$(trinket_run_env_repo_root)"
  TRINKET_REPO_ROOT="$root"
  shared="$(trinket_run_env_shared_root)"
  TRINKET_SHARED_DERIVED_DATA="$shared"

  if [[ -z "${TRINKET_ISOLATE:-}" && -n "${TRINKET_RUN_ID:-}" ]]; then
    TRINKET_ISOLATE=1
  fi

  [[ -n "${DERIVED_DATA_PATH:-}" ]] && derived_explicit=1
  [[ -n "${TRINKET_SIMULATOR_NAME:-}" ]] && sim_explicit=1

  TRINKET_GENERATE_LOCK_DIR="${TRINKET_GENERATE_LOCK_DIR:-$shared/.generate.lock}"
  TRINKET_XCODEGEN_CACHE_PATH="${TRINKET_XCODEGEN_CACHE_PATH:-$shared/XcodeGen.cache}"
  TRINKET_UI_ACTIVE_DIR="${TRINKET_UI_ACTIVE_DIR:-$shared/.active-ui}"
  TRINKET_SIM_ACTIVE_DIR="${TRINKET_SIM_ACTIVE_DIR:-$shared/.active-sim}"
  TRINKET_MAX_CONCURRENT_UI="${TRINKET_MAX_CONCURRENT_UI:-2}"
  TRINKET_MAX_AGENT_SIMS="${TRINKET_MAX_AGENT_SIMS:-1}"
  TRINKET_GENERATE_LOCK_TIMEOUT_SECONDS="${TRINKET_GENERATE_LOCK_TIMEOUT_SECONDS:-120}"

  if [[ "${TRINKET_ISOLATE:-}" == "1" ]]; then
    if [[ -z "${TRINKET_RUN_ID:-}" ]]; then
      TRINKET_RUN_ID="$$-$(date -u +%Y%m%dT%H%M%SZ)-${RANDOM:-0}"
    fi
    TRINKET_DIAGNOSTICS_SESSION_ID="${TRINKET_DIAGNOSTICS_SESSION_ID:-$TRINKET_RUN_ID}"

    if [[ "$derived_explicit" -eq 1 && "$sim_explicit" -eq 1 ]]; then
      : # caller pinned both; skip slot pool
    elif [[ -n "${TRINKET_AGENT_SLOT:-}" ]]; then
      # Parent already holds the slot lock; bind paths only.
      [[ "$sim_explicit" -eq 1 ]] || TRINKET_SIMULATOR_NAME=""
      [[ "$derived_explicit" -eq 1 ]] || DERIVED_DATA_PATH=""
      trinket_bind_agent_slot "$TRINKET_AGENT_SLOT"
    elif [[ "${TRINKET_SIM_SLOT_SKIP_ACQUIRE:-}" == "1" ]]; then
      # Dry-run / preview: show pool intent without locking a slot.
      if [[ "$derived_explicit" -eq 0 ]]; then
        DERIVED_DATA_PATH="$shared/runs/agent-preview"
      fi
      if [[ "$sim_explicit" -eq 0 ]]; then
        TRINKET_SIMULATOR_NAME="Trinket Agent (pool)"
      fi
    else
      [[ "$sim_explicit" -eq 1 ]] || TRINKET_SIMULATOR_NAME=""
      [[ "$derived_explicit" -eq 1 ]] || DERIVED_DATA_PATH=""
      trinket_sim_slot_acquire || return 1
    fi
  else
    if [[ -z "${DERIVED_DATA_PATH:-}" ]]; then
      DERIVED_DATA_PATH="$shared"
    fi
    if [[ -z "${TRINKET_SIMULATOR_NAME:-}" ]]; then
      TRINKET_SIMULATOR_NAME="Trinket CI"
    fi
    TRINKET_DIAGNOSTICS_SESSION_ID="${TRINKET_DIAGNOSTICS_SESSION_ID:-}"
  fi

  if [[ -z "${RESULTS_DIR:-}" ]]; then
    RESULTS_DIR="$DERIVED_DATA_PATH/TestResults"
  fi

  if [[ "${TRINKET_ISOLATE:-}" == "1" ]]; then
    export TMPDIR="$DERIVED_DATA_PATH/tmp"
    export TMP="$TMPDIR"
    export TEMP="$TMPDIR"
    mkdir -p "$TMPDIR"
  fi

  mkdir -p "$DERIVED_DATA_PATH" "$RESULTS_DIR" "$shared"

  export TRINKET_REPO_ROOT TRINKET_SHARED_DERIVED_DATA
  export TRINKET_ISOLATE TRINKET_RUN_ID DERIVED_DATA_PATH RESULTS_DIR
  export TRINKET_SIMULATOR_NAME TRINKET_GENERATE_LOCK_DIR TRINKET_XCODEGEN_CACHE_PATH
  export TRINKET_UI_ACTIVE_DIR TRINKET_SIM_ACTIVE_DIR
  export TRINKET_MAX_CONCURRENT_UI TRINKET_MAX_AGENT_SIMS
  export TRINKET_GENERATE_LOCK_TIMEOUT_SECONDS TRINKET_DIAGNOSTICS_SESSION_ID
  export TRINKET_AGENT_SLOT
}

trinket_run_env_print() {
  local isolate_label="shared"
  local slot_label="none"
  [[ "${TRINKET_ISOLATE:-}" == "1" ]] && isolate_label="isolated"
  [[ -n "${TRINKET_AGENT_SLOT:-}" ]] && slot_label="$TRINKET_AGENT_SLOT"
  printf 'run-env mode=%s run_id=%s agent_slot=%s derived=%s results=%s sim=%s\n' \
    "$isolate_label" \
    "${TRINKET_RUN_ID:-none}" \
    "$slot_label" \
    "${DERIVED_DATA_PATH:-unset}" \
    "${RESULTS_DIR:-unset}" \
    "${TRINKET_SIMULATOR_NAME:-unset}"
}

trinket_ui_slot_reap() {
  local active_dir="${TRINKET_UI_ACTIVE_DIR:-$(trinket_run_env_shared_root)/.active-ui}"
  [[ -d "$active_dir" ]] || return 0
  local slot pid
  for slot in "$active_dir"/*.slot; do
    [[ -e "$slot" ]] || continue
    pid=""
    if [[ -f "$slot" ]]; then
      # shellcheck disable=SC2034
      read -r pid _ < "$slot" || true
    fi
    if [[ "$pid" =~ ^[0-9]+$ ]] && ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$slot"
    fi
  done
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

trinket_ui_slot_release() {
  local current_owner="${BASHPID:-$$}:${BASH_SUBSHELL:-0}"
  if [[ -n "${TRINKET_UI_SLOT_PATH:-}" \
    && "${TRINKET_UI_SLOT_OWNER_PID:-}" == "$current_owner" \
    && -e "${TRINKET_UI_SLOT_PATH}" ]]; then
    rm -f "$TRINKET_UI_SLOT_PATH"
  fi
  TRINKET_UI_SLOT_PATH=""
  TRINKET_UI_SLOT_OWNER_PID=""
}

# Acquire a UI/smoke concurrency slot. Fail-fast when at capacity — never wait.
trinket_ui_slot_acquire() {
  local max="${TRINKET_MAX_CONCURRENT_UI:-2}"
  local active_dir="${TRINKET_UI_ACTIVE_DIR:-$(trinket_run_env_shared_root)/.active-ui}"
  local slot_name count lock_path lock_pid owner_pid owner_token
  owner_pid="$$"
  owner_token="${BASHPID:-$$}:${BASH_SUBSHELL:-0}"
  mkdir -p "$active_dir"
  trinket_ui_slot_reap

  # Reserve the count/check/create sequence with an atomic lock file.  A
  # plain count followed by a write lets concurrent callers exceed the cap.
  lock_path="$active_dir/.acquire.lock"
  if [[ -e "$lock_path" ]]; then
    lock_pid=""
    read -r lock_pid _ < "$lock_path" || true
    if [[ "$lock_pid" =~ ^[0-9]+$ ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
      rm -f "$lock_path"
    fi
  fi
  if ! ( set -o noclobber; printf '%s %s\n' "$owner_pid" "${TRINKET_RUN_ID:-shared}" > "$lock_path" ) 2>/dev/null; then
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
