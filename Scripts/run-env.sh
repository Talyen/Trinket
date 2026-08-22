#!/usr/bin/env bash
# Shared run-tenant setup for build/test wrappers.
#
# Source this file, then call trinket_run_env_init once near script start.
# Default (no isolate): $PWD/.DerivedData + simulator "Trinket Run"
# (human `run` alias and local tests — not GitHub Actions).
# Isolated (TRINKET_ISOLATE=1): acquires a reusable agent simulator slot
# (Trinket Agent N) with DerivedData under .DerivedData/runs/agent-N/.
#
# On self-clean start + EXIT (top-level owner only): reclaim Preview sims when
# the Preview device set is non-empty, enforce exactly one Booted managed sim
# (Agent or Run), age-prune bulky artifacts, and remove passed test diagnostics.
# The keep-target stays Booted
# (no routine erase — avoids CrashReporter sheets from guest apps). Nested
# children release leases only. xcode-runner wall/idle watchdogs kill host
# xcodebuild trees only; they never call simctl.
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

trinket_simctl_json() {
  python3 "$(trinket_run_env_repo_root)/Scripts/simctl_json.py" "$@"
}

trinket_simulator_is_shared_name() {
  local name="$1"
  # "Trinket CI" is the pre-rename shared human simulator.
  [[ "$name" == "Trinket Run" || "$name" == "Trinket CI" ]]
}

trinket_simulator_is_managed_name() {
  local name="$1"
  trinket_simulator_is_shared_name "$name" || [[ "$name" =~ ^Trinket\ Agent\ [0-9]+$ ]]
}

trinket_simulator_is_active_agent_name() {
  local name="$1"
  [[ "$name" =~ ^Trinket\ Agent\ ([0-9]+)$ ]] \
    && [[ -e "${TRINKET_SIM_ACTIVE_DIR:-$(trinket_run_env_shared_root)/.active-sim}/${BASH_REMATCH[1]}.slot" ]]
}

# Gracefully stop PosterBoard and wait for simulator process teardown before erase/delete.
# A real shutdown can take tens of seconds; erase/delete against a device that is still
# shutting down fails silently and cascades into a full recreate, so wait with headroom.
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

  local waited=0
  while (( waited < timeout_seconds )); do
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
    ((waited++))
  done
  echo "warning: simulator did not reach Shutdown within ${timeout_seconds}s (udid: $udid)" >&2
}

# Reclaim Xcode Preview simulator devices when the Preview set has entries.
# Always prune leftover device dirs under literal and URL-encoded Previews paths.
# simctl shutdown/delete only runs in CI (or when TRINKET_CLEANUP_PREVIEW_SIMS=1):
# local simctl teardown can trigger needless CrashReporter sheets.
trinket_preview_sims_reclaim() {
  local previews_root="${HOME}/Library/Developer/Xcode/UserData/Previews"
  local dir
  for dir in \
    "${previews_root}/Simulator Devices" \
    "${previews_root}/Simulator%20Devices"
  do
    [[ -d "$dir" ]] || continue
    find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} + >/dev/null 2>&1 || true
  done

  local default_cleanup="0"
  if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
    default_cleanup="1"
  fi
  local enabled="${TRINKET_CLEANUP_PREVIEW_SIMS:-$default_cleanup}"
  [[ "$enabled" == "1" ]] || return 0

  local preview_counts=""
  # simctl --set previews may print a device-set banner before JSON; keep from '{'.
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

# Remove rebuildable DerivedData caches while retaining Build/Products,
# ModuleCache, and SourcePackages for warm --no-build runs. Callers own target
# validation; this helper only owns the shared path set.
trinket_prune_rebuildable_derived_data() {
  local target="$1"
  rm -rf \
    "$target/Build/Intermediates.noindex" \
    "$target/Build/ProfileData" \
    "$target/Index.noindex" \
    "$target/Index" \
    "$target/SymbolCache" \
    "$target/SDKStatCaches.noindex" \
    "$target/CompilationCache.noindex" \
    "$target/Logs" \
    2>/dev/null || true
}

# Age-prune bulky rebuildable artifacts under the shared .DerivedData root and
# package-local build trees. Keeps warm runs/agent-N Build products; never wipes
# Intermediates by default. Does not touch ~/Library/Developer/Xcode/DerivedData.
trinket_derived_data_age_prune() {
  [[ "${TRINKET_CLEANUP_DERIVED_DATA_AGE_PRUNE:-1}" == "1" ]] || return 0
  local shared_root="${TRINKET_SHARED_DERIVED_DATA:-$(trinket_run_env_shared_root)}"
  local max_age_days="${TRINKET_RUN_MAX_AGE_DAYS:-3}"
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
          find "$root/$name" -mindepth 1 -maxdepth 1 -mtime "+${max_age_days}" \
            -exec rm -rf {} + 2>/dev/null || true
        fi
      done
    done
  fi

  # Package-local SPM / Xcode package caches (gitignored).
  local package_dir
  if [[ -d "$repo_root/BalanceSweepReports" ]]; then
    find "$repo_root/BalanceSweepReports" -mindepth 1 -maxdepth 1 -mtime "+${max_age_days}" \
      -exec rm -rf {} + 2>/dev/null || true
  fi
  if [[ -d "$repo_root/Packages" ]]; then
    # Shared Packages/.DerivedData is a parallel-build lock hazard (SPM package
    # schemes used to race one build.db here). Always remove it; package builds
    # pin SYMROOT/OBJROOT under $DERIVED_DATA_PATH/packages/<name>/.
    if [[ -d "$repo_root/Packages/.DerivedData" ]]; then
      rm -rf "$repo_root/Packages/.DerivedData" 2>/dev/null || true
    fi
    for package_dir in "$repo_root/Packages"/*; do
      [[ -d "$package_dir" ]] || continue
      for name in .build .DerivedData; do
        if [[ -d "$package_dir/$name" ]]; then
          find "$package_dir/$name" -mindepth 0 -maxdepth 0 -mtime "+${max_age_days}" \
            -exec rm -rf {} + 2>/dev/null || true
        fi
      done
    done
  fi
}

# Shared lock for the simulator cleanup policies. Acquires a noclobber lock at
# <shared_root>/.simulator-cleanup.lock, reaping a stale holder first. Returns 0
# when this process owns the lock, 1 when a live peer owns it (the caller decides
# whether to proceed or skip). The owner must call
# trinket_sim_cleanup_lock_release afterwards.
trinket_sim_cleanup_lock_try_acquire() {
  local shared_root="$1"
  local lock_path="$shared_root/.simulator-cleanup.lock"
  local lock_pid=""
  mkdir -p "$shared_root"

  if [[ -e "$lock_path" ]]; then
    read -r lock_pid _ < "$lock_path" || true
    # Reap any non-live holder: a dead pid or a malformed/partial lock written
    # by a crashed peer (non-numeric content would otherwise never clear).
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

# Keep exactly one Booted managed sim (Trinket Run / Trinket Agent N). Quietly
# shut down the rest; never erase. Default on for self-clean start + EXIT.
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

  # Prefer: held agent slot → TRINKET_SIMULATOR_NAME → Trinket Run → first.
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
}

# Preview reclaim + single-warm + age-prune. Used on self-clean start and EXIT.
trinket_run_env_self_clean_hygiene() {
  trinket_preview_sims_reclaim
  trinket_simulator_enforce_single_warm_booted
  trinket_derived_data_age_prune
}

trinket_run_env_cleanup_test_artifacts() {
  [[ "${TRINKET_CLEANUP_TEST_ARTIFACTS:-1}" == "1" ]] || return 0
  [[ -n "${RESULTS_DIR:-}" && "$(basename "$RESULTS_DIR")" == "TestResults" ]] || return 0
  "$(trinket_run_env_repo_root)/Scripts/ci-diagnostics.sh" --cleanup "$RESULTS_DIR" >/dev/null 2>&1 || true
}

# Identity of this exact shell: BASHPID is unavailable in macOS Bash 3.2, so
# BASH_SUBSHELL distinguishes a same-shell `( ... )` child while $$ distinguishes
# a new bash process.
trinket_slot_owner_token() {
  printf '%s' "${BASHPID:-$$}:${BASH_SUBSHELL:-0}"
}

# Atomically create a lock/lease file with noclobber. Returns 0 when this caller
# created it, 1 when it already exists.
trinket_lock_claim_file() {
  ( set -o noclobber; printf '%s\n' "$2" > "$1" ) 2>/dev/null
}

# Claim once per process tree. Nested children inherit the parent token and must
# not overwrite it — otherwise every child EXIT would wipe Previews mid-plan.
trinket_run_env_claim_self_clean_owner() {
  if [[ -z "${TRINKET_SELF_CLEAN_OWNER:-}" ]]; then
    TRINKET_SELF_CLEAN_OWNER="$(trinket_slot_owner_token)"
    export TRINKET_SELF_CLEAN_OWNER
  fi
}

trinket_run_env_release_slots() {
  trinket_sim_slot_release
  trinket_ui_slot_release
  trinket_shared_sim_lease_release
  # Self-clean only for the top-level owner (verify/test parent). Children that
  # inherit the trap still release their own leases, but skip Preview / single-
  # warm / age-prune so a mid-plan child EXIT cannot disrupt peers or Xcode Previews.
  local current_owner
  current_owner="$(trinket_slot_owner_token)"
  if [[ "${TRINKET_SELF_CLEAN_OWNER:-}" == "$current_owner" ]]; then
    trinket_run_env_self_clean_hygiene
    trinket_run_env_cleanup_test_artifacts
  fi
}

trinket_run_env_install_release_trap() {
  trap 'trinket_run_env_release_slots' EXIT INT TERM
}

# Top-level verify/test: claim self-clean, run start hygiene, install EXIT release.
trinket_run_env_install_self_clean() {
  trinket_run_env_claim_self_clean_owner
  local current_owner
  current_owner="$(trinket_slot_owner_token)"
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

# A slot/lease entry ("pid run-id ISO-timestamp") is stale when its pid is dead
# OR its timestamp exceeds TRINKET_SLOT_STALE_SECONDS (default 6h). The age cap
# covers pid reuse: a recycled pid otherwise keeps a dead run's lease alive
# forever and permanently fail-fails pool acquisition.
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
  # A child process inherits the parent's lease path.  Only the process that
  # claimed the lease may remove it; otherwise a UI child can release the
  # parent's simulator while the parent is still running.
  trinket_release_owned_slot "${TRINKET_SIM_SLOT_PATH:-}" "${TRINKET_SIM_SLOT_OWNER_PID:-}"
  TRINKET_SIM_SLOT_PATH=""
  TRINKET_SIM_SLOT_OWNER_PID=""
}

# Agents stay warm after release (no routine shutdown/erase).
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
    # Claim with noclobber to avoid two agents racing the same index.
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

# Lease the shared human device (Trinket Run) so two non-isolated runs collide
# with a clear error instead of silently fighting over boot/erase state and
# DerivedData. Fail-fast, same contract as the agent-slot pool.
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

trinket_shared_sim_lease_release() {
  if [[ -n "${TRINKET_SHARED_SIM_SLOT_PATH:-}" && -e "${TRINKET_SHARED_SIM_SLOT_PATH}" ]]; then
    local pid=""
    read -r pid _ < "${TRINKET_SHARED_SIM_SLOT_PATH}" 2>/dev/null || true
    # Only our own lease — or a stale one — may be cleared.
    if [[ "$pid" == "$$" ]] || trinket_slot_entry_is_stale "${TRINKET_SHARED_SIM_SLOT_PATH}"; then
      rm -f "${TRINKET_SHARED_SIM_SLOT_PATH}"
    fi
  fi
  TRINKET_SHARED_SIM_SLOT_PATH=""
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
      TRINKET_SIMULATOR_NAME="Trinket Run"
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
  local sim_role="human run / local tests"
  [[ "${TRINKET_ISOLATE:-}" == "1" ]] && sim_role="Cursor agent isolate"
  printf 'run-env mode=%s run_id=%s agent_slot=%s derived=%s results=%s sim=%s (%s)\n' \
    "$isolate_label" \
    "${TRINKET_RUN_ID:-none}" \
    "$slot_label" \
    "${DERIVED_DATA_PATH:-unset}" \
    "${RESULTS_DIR:-unset}" \
    "${TRINKET_SIMULATOR_NAME:-unset}" \
    "$sim_role"
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

trinket_ui_slot_release() {
  trinket_release_owned_slot "${TRINKET_UI_SLOT_PATH:-}" "${TRINKET_UI_SLOT_OWNER_PID:-}"
  TRINKET_UI_SLOT_PATH=""
  TRINKET_UI_SLOT_OWNER_PID=""
}

# Acquire a UI/smoke concurrency slot. Fail-fast when at capacity — never wait.
trinket_ui_slot_acquire() {
  local max="${TRINKET_MAX_CONCURRENT_UI:-2}"
  local active_dir="${TRINKET_UI_ACTIVE_DIR:-$(trinket_run_env_shared_root)/.active-ui}"
  local slot_name count lock_path lock_pid owner_pid owner_token
  owner_pid="$$"
  owner_token="$(trinket_slot_owner_token)"
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
