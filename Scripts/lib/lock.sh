#!/usr/bin/env bash
# Shared file-lock helpers — single source for generation, simulator slot,
# and performance-profile locks that were previously copy-pasted.
# shellcheck disable=SC2034

# Acquires an exclusive directory lock at `lock_dir` with a timeout.
# On success leaves `$lock_dir/pid` containing the holder PID and traps EXIT cleanup.
# Usage: trinket_dir_lock_acquire <lock_dir> <timeout_seconds>
trinket_dir_lock_acquire() {
  local lock_dir="$1"
  local timeout_seconds="$2"
  local started_at=$SECONDS
  local lock_pid=""

  mkdir -p "$(dirname "$lock_dir")"

  # Expand now so the EXIT trap captures the current lock path/pid (locals are gone at trap time).
  # shellcheck disable=SC2064
  trap "trinket_dir_lock_release \"$lock_dir\" \"$$\"" EXIT INT TERM

  while ! mkdir "$lock_dir" 2>/dev/null; do
    lock_pid=""
    if [[ -f "$lock_dir/pid" ]]; then
      read -r lock_pid < "$lock_dir/pid" 2>/dev/null || true
    fi
    if [[ "$lock_pid" =~ ^[0-9]+$ ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
      rm -rf "$lock_dir"
      continue
    fi
    if (( SECONDS - started_at >= timeout_seconds )); then
      echo "Lock timed out after ${timeout_seconds}s at $lock_dir." >&2
      if [[ "$lock_pid" =~ ^[0-9]+$ ]]; then
        echo "Held by pid $lock_pid. Do not kill foreign processes." >&2
      fi
      return 1
    fi
    sleep 1
  done
  printf '%s\n' "$$" > "$lock_dir/pid"
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
