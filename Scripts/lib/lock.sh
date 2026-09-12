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
  trinket_lock_collect_children "${BASHPID:-$$}"
  if (( ${#signal_children[@]} > 0 )); then
    kill -TERM "${signal_children[@]}" 2>/dev/null || true
    sleep 2
    kill -KILL "${signal_children[@]}" 2>/dev/null || true
    wait 2>/dev/null || true
  fi
  exit "$status"
}

# Resource cleanup belongs to EXIT, after cancellation stops owned children.
trinket_dir_lock_chain_trap() {
  local new_step="$1"
  local existing=""
  existing="$(trap -p EXIT)"
  if [[ -n "$existing" ]]; then
    existing="${existing#trap -- }"
    existing="${existing% EXIT}"
    eval "existing=$existing"
  fi
  if [[ -n "$existing" && "$existing" != *"$new_step"* ]]; then
    # shellcheck disable=SC2064
    trap "$new_step; $existing" EXIT
  elif [[ -z "$existing" ]]; then
    # shellcheck disable=SC2064
    trap "$new_step" EXIT
  fi
  trap 'trinket_lock_exit_on_signal 130' INT
  trap 'trinket_lock_exit_on_signal 143' TERM
}

# Acquires a directory lock, records its owner, and chains release onto EXIT.
trinket_dir_lock_acquire() {
  local lock_dir="$1"
  local timeout_seconds="$2"
  local started_at=$SECONDS
  local lock_pid=""

  mkdir -p "$(dirname "$lock_dir")"

  # Expand now so the EXIT trap captures the current lock path/pid (locals are gone at trap time).
  local cleanup
  printf -v cleanup 'trinket_dir_lock_release %q %q' "$lock_dir" "${BASHPID:-$$}"
  trinket_dir_lock_chain_trap "$cleanup"

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
  printf '%s\n' "${BASHPID:-$$}" > "$lock_dir/pid"
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
