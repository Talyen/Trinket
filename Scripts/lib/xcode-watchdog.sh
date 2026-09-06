#!/usr/bin/env bash

xcode_runner_wall_timeout_seconds() {
  printf '%s' "${TRINKET_XCODE_WALL_TIMEOUT_SECONDS:-1200}"
}

xcode_runner_idle_timeout_seconds() {
  local raw="${TRINKET_XCODE_IDLE_TIMEOUT_SECONDS:-}"
  if [[ -z "$raw" ]]; then
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
      printf '45'
    else
      printf '10'
    fi
    return
  fi
  printf '%s' "$raw"
}

xcode_runner_watchdog_enabled() {
  local wall idle
  wall="$(xcode_runner_wall_timeout_seconds)"
  idle="$(xcode_runner_idle_timeout_seconds)"
  [[ "$wall" =~ ^[0-9]+$ ]] || wall=0
  [[ "$idle" =~ ^[0-9]+$ ]] || idle=0
  (( wall > 0 || idle > 0 ))
}

xcode_runner_log_byte_size() {
  local log_file="$1"
  if [[ -f "$log_file" ]]; then
    wc -c <"$log_file" | tr -d '[:space:]'
  else
    printf '0'
  fi
}

xcode_runner_log_has_terminal_marker() {
  local log_file="$1"
  xcode_runner_scan_terminal_marker_from "$log_file" 0
}

xcode_runner_scan_terminal_marker_from() {
  local log_file="$1"
  local offset="$2"
  [[ -f "$log_file" ]] || return 1
  tail -c +"$((offset + 1))" "$log_file" 2>/dev/null | grep -Eq \
    "Test Suite '(Selected tests|All tests)' (passed|failed)|\\*\\* (TEST|BUILD) (SUCCEEDED|FAILED) \\*\\*|Testing started completed|✘ Test run with |✔ Test run with "
}

xcode_runner_infer_exit_from_log() {
  local log_file="$1"
  [[ -f "$log_file" ]] || {
    printf '124'
    return
  }
  if grep -Eq "\\*\\* (TEST|BUILD) FAILED \\*\\*|✘ (Test|Suite) .* (failed|recorded an issue)|Test (Case|Suite) .* failed|error:.*(XCTAssert|Expectation failed)|Restarting after unexpected exit" "$log_file"; then
    printf '65'
    return
  fi
  if grep -Eq "\\*\\* (TEST|BUILD) SUCCEEDED \\*\\*|✔ Test run with |Test Suite '(Selected tests|All tests)' passed" "$log_file"; then
    printf '0'
    return
  fi
  printf '124'
}

xcode_runner_kill_tree_impl() {
  local pid="$1"
  local signal="$2"
  local child
  [[ -n "$pid" ]] || return 0
  for child in $(pgrep -P "$pid" 2>/dev/null || true); do
    xcode_runner_kill_tree_impl "$child" "$signal"
  done
  kill "-$signal" "$pid" 2>/dev/null || true
}

xcode_runner_kill_tree() {
  xcode_runner_kill_tree_impl "$1" TERM
}

xcode_runner_force_kill_tree() {
  xcode_runner_kill_tree_impl "$1" KILL
}

xcode_runner_execute_watched() {
  local log_file="$1"
  local working_directory="${2:-}"
  shift 2
  local wall idle
  local cmd_pid=0
  local started_at last_growth last_size size
  local saw_terminal=false
  local kill_reason=""
  local wait_status=0
  local inferred=124

  XCODE_RUNNER_COMPLETION_SOURCE="process-exit"
  export XCODE_RUNNER_COMPLETION_SOURCE

  wall="$(xcode_runner_wall_timeout_seconds)"
  idle="$(xcode_runner_idle_timeout_seconds)"
  [[ "$wall" =~ ^[0-9]+$ ]] || wall=0
  [[ "$idle" =~ ^[0-9]+$ ]] || idle=0

  mkdir -p "$(dirname "$log_file")"
  : >"$log_file"

  if [[ -n "$working_directory" ]]; then
    (
      cd "$working_directory" || exit 127
      exec "$@"
    ) >>"$log_file" 2>&1 &
    cmd_pid=$!
  else
    "$@" >>"$log_file" 2>&1 &
    cmd_pid=$!
  fi

  started_at=$SECONDS
  last_growth=$SECONDS
  last_size="$(xcode_runner_log_byte_size "$log_file")"
  local scanned_offset=0

  while kill -0 "$cmd_pid" 2>/dev/null; do
    sleep 1
    size="$(xcode_runner_log_byte_size "$log_file")"
    if (( size > last_size )); then
      last_size=$size
      last_growth=$SECONDS
    fi
    if [[ "$saw_terminal" == "false" ]]; then
      if (( size < scanned_offset )); then
        scanned_offset=0
      fi
      if (( size > scanned_offset )) && xcode_runner_scan_terminal_marker_from "$log_file" "$scanned_offset"; then
        saw_terminal=true
        last_growth=$SECONDS
      fi
      scanned_offset=$size
    fi
    if (( wall > 0 && SECONDS - started_at >= wall )); then
      kill_reason="wall-clock ${wall}s"
      break
    fi
    if [[ "$saw_terminal" == "true" ]] && (( idle > 0 && SECONDS - last_growth >= idle )); then
      kill_reason="idle log ${idle}s after terminal marker"
      break
    fi
  done

  if [[ -n "$kill_reason" ]]; then
    echo "xcode-runner: killing hung command ($kill_reason); log: $log_file" >&2
    xcode_runner_kill_tree "$cmd_pid"
    sleep 2
    if kill -0 "$cmd_pid" 2>/dev/null; then
      xcode_runner_force_kill_tree "$cmd_pid"
    fi
    wait "$cmd_pid" 2>/dev/null || true
    inferred="$(xcode_runner_infer_exit_from_log "$log_file")"
    if [[ "$inferred" -eq 124 ]]; then
      echo "xcode-runner: no TEST/BUILD result in log; treating as timeout (exit 124)." >&2
    else
      echo "xcode-runner: inferred exit $inferred from log after hang kill." >&2
      XCODE_RUNNER_COMPLETION_SOURCE="watchdog-log-inference"
      export XCODE_RUNNER_COMPLETION_SOURCE
    fi
    return "$inferred"
  fi

  wait_status=0
  wait "$cmd_pid" || wait_status=$?
  return "$wait_status"
}
