#!/usr/bin/env bash

# Shared tracked-tempfile helpers — single source for the mktemp + trap
# cleanup previously copy-pasted across stage/generate/analyze/run gates.
# Sourcing this file has no side effects beyond an empty tracking array;
# cleanup is chained onto EXIT (with signal handling) on first use via
# lib/lock.sh, so callers never restate trap lines. Safe to source twice.
#
# Paths are assigned with printf -v (never command substitution): capturing
# through $(...) forks a subshell whose EXIT trap would delete the path and
# whose tracking-array update would be lost.
#
# Subshells inherit both the tracking array and the EXIT trap: a ( ... ) body
# that tracks its own temps must reset TRINKET_TEMP_TRACKED=() first, or its
# EXIT will delete paths the parent still needs.
[[ -n "${_TRINKET_TEMPDIR_SH_LOADED:-}" ]] && return 0
_TRINKET_TEMPDIR_SH_LOADED=1

# shellcheck source=lock.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lock.sh"

TRINKET_TEMP_TRACKED=()

# Remove every tracked path. Idempotent; safe to call early for partial
# cleanup (remaining paths are still removed at EXIT).
trinket_temp_cleanup_all() {
  local path
  for path in ${TRINKET_TEMP_TRACKED[@]+"${TRINKET_TEMP_TRACKED[@]}"}; do
    [[ -n "$path" ]] && rm -rf "$path"
  done
  TRINKET_TEMP_TRACKED=()
}

# Track existing paths for EXIT cleanup.
# Usage: trinket_temp_track "$snapshot" "$snapshot.log"
trinket_temp_track() {
  local path
  for path in "$@"; do
    TRINKET_TEMP_TRACKED+=("$path")
  done
  trinket_dir_lock_chain_trap trinket_temp_cleanup_all
}

# Stop tracking paths so EXIT cleanup leaves them behind (failure evidence).
# Usage: trinket_temp_untrack "$snapshot" "$snapshot.log"
trinket_temp_untrack() {
  local path keep
  local -a remaining=()
  for path in ${TRINKET_TEMP_TRACKED[@]+"${TRINKET_TEMP_TRACKED[@]}"}; do
    keep=1
    local drop
    for drop in "$@"; do
      [[ "$path" == "$drop" ]] && keep=0
    done
    (( keep )) && remaining+=("$path")
  done
  TRINKET_TEMP_TRACKED=("${remaining[@]+"${remaining[@]}"}")
}

# Assign a tracked mktemp -d to <var>: ${TMPDIR:-/tmp}/<prefix>.XXXXXX.
# Usage: trinket_mktemp_dir snapshot trinket-staged-project
trinket_mktemp_dir() {
  local _var="$1" _prefix="${2:-trinket}" _dir
  _dir="$(mktemp -d "${TMPDIR:-/tmp}/${_prefix}.XXXXXX")" || return 1
  printf -v "$_var" '%s' "$_dir"
  trinket_temp_track "$_dir"
}

# Assign a tracked mktemp file to <var>: ${TMPDIR:-/tmp}/<prefix>.XXXXXX.
# Usage: trinket_mktemp_file report trinket-budget-stats
trinket_mktemp_file() {
  local _var="$1" _prefix="${2:-trinket}" _file
  _file="$(mktemp "${TMPDIR:-/tmp}/${_prefix}.XXXXXX")" || return 1
  printf -v "$_var" '%s' "$_file"
  trinket_temp_track "$_file"
}
