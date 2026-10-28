#!/usr/bin/env bash
# Shared file-lock helpers — single source for generation, simulator slot,
# and performance-profile locks that were previously copy-pasted.
# shellcheck disable=SC2034

# Capture descendants before signalling so reparented workers remain ours to stop.
trinket_lock_collect_children() {
  local child
  for child in $(pgrep -P "$1" 2>/dev/null || true); do
    trinket_lock_collect_children "$child"
    signal_children+=("$child")
  done
}

trinket_lock_exit_on_signal() {
  local status="$1"
  local signal_children=()
  trap '' INT TERM
  local owner_pid="${BASHPID:-}"
  [[ -n "$owner_pid" ]] || owner_pid="$(exec /bin/sh -c 'echo "$PPID"')"
  trinket_lock_collect_children "$owner_pid"
  if (( ${#signal_children[@]} > 0 )); then
    kill -TERM "${signal_children[@]}" 2>/dev/null || true
    sleep 2
    kill -KILL "${signal_children[@]}" 2>/dev/null || true
    wait 2>/dev/null || true
  fi
  exit "$status"
}

# Resource cleanup belongs to EXIT, after cancellation stops owned children.
trinket_dir_lock_run_exit_steps() {
  local _trinket_exit_status="$1" _trinket_step
  # Restore the shell's positional arguments for existing trap expressions.
  shift
  for _trinket_step in "${TRINKET_EXIT_STEPS[@]}"; do
    # Each trap must see the original exit status, even after a successful
    # cleanup. The conditional also preserves nonzero status under errexit.
    if (exit "$_trinket_exit_status"); then
      eval "$_trinket_step"
    else
      eval "$_trinket_step"
    fi
  done
}

trinket_dir_lock_chain_trap() {
  local new_step="$1"
  local existing=""
  local dispatcher='trinket_dir_lock_run_exit_steps "$?" "$@"'
  existing="$(trap -p EXIT)"
  if [[ -n "$existing" ]]; then
    existing="${existing#trap -- }"
    existing="${existing% EXIT}"
    eval "existing=$existing"
  fi
  if [[ "$existing" != "$dispatcher" ]]; then
    TRINKET_EXIT_STEPS=()
    [[ -z "$existing" ]] || TRINKET_EXIT_STEPS+=("$existing")
  fi
  local step found=false
  for step in "${TRINKET_EXIT_STEPS[@]+"${TRINKET_EXIT_STEPS[@]}"}"; do
    [[ "$step" != "$new_step" ]] || found=true
  done
  if [[ "$found" == false ]]; then
    TRINKET_EXIT_STEPS=("$new_step" "${TRINKET_EXIT_STEPS[@]+"${TRINKET_EXIT_STEPS[@]}"}")
  fi
  trap 'trinket_dir_lock_run_exit_steps "$?" "$@"' EXIT
  trap 'trinket_lock_exit_on_signal 130' INT
  trap 'trinket_lock_exit_on_signal 143' TERM
}

# True when <pid> is a numeric pid with no live process. A missing or
# non-numeric pid is NOT stale here: preserve locks whose owner is unknown.
trinket_lock_pid_is_stale() {
  [[ "${1:-}" =~ ^[0-9]+$ ]] || return 1
  python3 - "$1" <<'PY_OWNER'
import os
import sys

try:
    pid = int(sys.argv[1])
    if pid <= 0:
        sys.exit(1)
    os.kill(pid, 0)
except ProcessLookupError:
    sys.exit(0)
except (OSError, ValueError, OverflowError):
    pass
# Permission denial and invalid/unknown identities never authorize reclamation.
sys.exit(1)
PY_OWNER
}

# Reclaim a stale file lock, or a directory lock with a separate pid file.
# The adjacent claim serializes stale observers across removal/recreation of
# the lock itself. Never reap this claim: interrupted recovery must fail closed.
trinket_lock_reclaim_stale() {
  local lock_path="$1" pid_path="${2:-$1}"
  local claim_path="$lock_path.reclaim" observed_pid="" current_pid="" result=1
  if [[ -f "$pid_path" ]]; then
    if [[ "$lock_path" == "$pid_path" ]]; then
      read -r observed_pid _ < "$pid_path" 2>/dev/null || true
    else
      read -r observed_pid < "$pid_path" 2>/dev/null || true
    fi
  fi
  trinket_lock_pid_is_stale "$observed_pid" || return 1
  mkdir "$claim_path" 2>/dev/null || return 1
  local owner_pid="${BASHPID:-}"
  [[ -n "$owner_pid" ]] || owner_pid="$(exec /bin/sh -c 'echo "$PPID"')"
  if ! printf '%s\n' "$owner_pid" > "$claim_path/pid"; then
    rm -f "$claim_path/pid"
    rmdir "$claim_path" 2>/dev/null || true
    return 1
  fi
  if [[ -f "$pid_path" ]]; then
    if [[ "$lock_path" == "$pid_path" ]]; then
      read -r current_pid _ < "$pid_path" 2>/dev/null || true
    else
      read -r current_pid < "$pid_path" 2>/dev/null || true
    fi
  fi
  if [[ "$current_pid" == "$observed_pid" ]] && trinket_lock_pid_is_stale "$current_pid"; then
    if [[ "$lock_path" == "$pid_path" ]]; then
      rm -f "$lock_path" && result=0
    else
      rm -rf "$lock_path" && result=0
    fi
  fi
  rm -f "$claim_path/pid"
  rmdir "$claim_path" 2>/dev/null || true
  return "$result"
}

# Acquires a directory lock, records its owner, and chains release onto EXIT.
trinket_dir_lock_acquire() {
  local lock_dir="$1"
  local timeout_seconds="$2"
  local started_at=$SECONDS
  local lock_pid=""
  # Bash 3.2 has no BASHPID; $$ still identifies the parent in a subshell.
  # An exec'd helper reports this shell's actual PID through its PPID.
  local owner_pid="${BASHPID:-}"
  [[ -n "$owner_pid" ]] || owner_pid="$(exec /bin/sh -c 'echo "$PPID"')"

  mkdir -p "$(dirname "$lock_dir")"

  # Expand now so the EXIT trap captures the current lock path/pid (locals are gone at trap time).
  local cleanup
  printf -v cleanup 'trinket_dir_lock_release %q %q' "$lock_dir" "$owner_pid"
  trinket_dir_lock_chain_trap "$cleanup"

  while ! mkdir "$lock_dir" 2>/dev/null; do
    if trinket_lock_reclaim_stale "$lock_dir" "$lock_dir/pid"; then
      continue
    fi
    lock_pid=""
    if [[ -f "$lock_dir/pid" ]]; then
      read -r lock_pid < "$lock_dir/pid" 2>/dev/null || true
    fi
    if (( SECONDS - started_at >= timeout_seconds )); then
      echo "Lock timed out after ${timeout_seconds}s at $lock_dir." >&2
      if [[ -d "$lock_dir.reclaim" ]]; then
        echo "Stale-lock recovery is already claimed at $lock_dir.reclaim; refusing another recovery." >&2
      fi
      if [[ "$lock_pid" =~ ^[0-9]+$ ]]; then
        echo "Held by pid $lock_pid. Do not kill foreign processes." >&2
      fi
      return 1
    fi
    sleep 1
  done
  printf '%s\n' "$owner_pid" > "$lock_dir/pid"
}

trinket_dir_lock_release() {
  local lock_dir="$1"
  local expected_pid="$2"
  if [[ -f "$lock_dir/pid" ]]; then
    local pid_in_lock=""
    read -r pid_in_lock < "$lock_dir/pid" 2>/dev/null || pid_in_lock=""
    if [[ "$pid_in_lock" == "$expected_pid" ]]; then
      rm -rf "$lock_dir"
    fi
  fi
}

# Atomic single-file claim via noclobber; 0 when this caller created the file.
# Used by slot allocation (slots.sh) and sim lease prep (simctl.sh).
trinket_lock_claim_file() {
  ( set -o noclobber; printf '%s\n' "$2" > "$1" ) 2>/dev/null
}
