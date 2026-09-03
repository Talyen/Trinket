#!/usr/bin/env bash
# Shared run-tenant setup for build/test wrappers.
#
# Source this file, then call trinket_run_env_init once near script start.
# Default (no isolate): $PWD/.DerivedData + simulator "Trinket Run"
# Isolated (TRINKET_ISOLATE=1): acquires a reusable agent simulator slot
# (Trinket Agent N) with DerivedData under .DerivedData/runs/agent-N/.

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

_TRINKET_RUN_ENV_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib"
# shellcheck source=lib/slots.sh
source "$_TRINKET_RUN_ENV_LIB_DIR/slots.sh"
# shellcheck source=lib/simctl.sh
source "$_TRINKET_RUN_ENV_LIB_DIR/simctl.sh"
# shellcheck source=lib/derived-data.sh
source "$_TRINKET_RUN_ENV_LIB_DIR/derived-data.sh"
unset _TRINKET_RUN_ENV_LIB_DIR

trinket_run_env_self_clean_hygiene() {
  trinket_preview_sims_reclaim
  trinket_simulator_enforce_single_warm_booted
  if [[ "${TRINKET_RUN_ENV_HYGIENE_PRUNE:-1}" == "1" ]]; then
    trinket_derived_data_age_prune
  fi
}

trinket_run_env_cleanup_test_artifacts() {
  [[ "${TRINKET_CLEANUP_TEST_ARTIFACTS:-1}" == "1" ]] || return 0
  [[ -n "${RESULTS_DIR:-}" && "$(basename "$RESULTS_DIR")" == "TestResults" ]] || return 0
  "$(trinket_run_env_repo_root)/Scripts/ci-diagnostics.sh" --cleanup "$RESULTS_DIR" >/dev/null 2>&1 || true
}

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

trinket_run_env_install_self_clean() {
  trinket_run_env_claim_self_clean_owner
  local current_owner
  current_owner="$(trinket_slot_owner_token)"
  if [[ "${TRINKET_SELF_CLEAN_OWNER:-}" == "$current_owner" ]]; then
    trinket_run_env_self_clean_hygiene
  fi
  trinket_run_env_install_release_trap
}

trinket_run_env_ensure_diagnostics_session() {
  if [[ -n "${TRINKET_DIAGNOSTICS_SESSION_ID:-}" ]]; then
    return 0
  fi
  if [[ -n "${TRINKET_RUN_ID:-}" ]]; then
    TRINKET_DIAGNOSTICS_SESSION_ID="$TRINKET_RUN_ID"
  else
    TRINKET_DIAGNOSTICS_SESSION_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM:-0}"
  fi
  export TRINKET_DIAGNOSTICS_SESSION_ID
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
    trinket_run_env_ensure_diagnostics_session
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
