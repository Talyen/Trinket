#!/usr/bin/env bash

# Shared xcodebuild orchestration.
#
# The runner is intentionally sourceable: the test/build wrappers retain
# ownership of their command-line contracts while this file owns log/result
# allocation, output policy, simulator retry, failure reporting, and hung-command
# watchdogs for quiet runs:
#   TRINKET_XCODE_WALL_TIMEOUT_SECONDS (default 1200; 0 disables)
#   TRINKET_XCODE_IDLE_TIMEOUT_SECONDS (default 45 after terminal marker; 0 disables)

XCODE_RUNNER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config/diagnostic-limits.env
source "$XCODE_RUNNER_SCRIPT_DIR/config/diagnostic-limits.env"

xcode_runner_sanitize_label() {
  local value="${1:-run}"
  value="${value//[^A-Za-z0-9_.-]/_}"
  [[ -n "$value" ]] || value="run"
  printf '%s' "$value"
}

xcode_runner_token() {
  # The pid and shell random value make concurrent wrapper invocations unique;
  # the existence check in xcode_runner_prepare closes the (rare) collision.
  printf '%s-%s-%s' "$(date -u +%Y%m%dT%H%M%SZ)" "$$" "${RANDOM:-0}"
}

xcode_runner_prepare() {
  local label="${1:-run}"
  local results_dir="${2:-${RESULTS_DIR:-${DERIVED_DATA_PATH:-$PWD/.DerivedData}/TestResults}}"
  local requested_prefix="${3:-}"
  local safe_label token result_bundle log_file report_prefix suffix=0

  safe_label="$(xcode_runner_sanitize_label "$label")"
  mkdir -p "$results_dir/raw"

  while :; do
    token="$(xcode_runner_token)"
    result_bundle="$results_dir/${safe_label}-${token}.xcresult"
    log_file="$results_dir/raw/${safe_label}-${token}.log"
    if [[ ! -e "$result_bundle" && ! -e "$log_file" ]]; then
      break
    fi
    suffix=$((suffix + 1))
    # Keep the loop bounded in practice while remaining deterministic in fake
    # Xcode/integration environments whose clock and pid may be fixed.
    if (( suffix > 100 )); then
      token="$(xcode_runner_token)-$suffix"
      result_bundle="$results_dir/${safe_label}-${token}.xcresult"
      log_file="$results_dir/raw/${safe_label}-${token}.log"
      break
    fi
  done

  if [[ -n "$requested_prefix" ]]; then
    report_prefix="$requested_prefix"
  else
    # Invocation reports stay at TestResults' top level so ci-diagnostics.sh
    # can discover them with its stable *-diagnostics.json glob. Attachments
    # remain siblings of the report and raw logs remain under raw/.
    report_prefix="$results_dir/${safe_label}-${token}-diagnostics"
  fi

  mkdir -p "$(dirname "$report_prefix")"
  XCODE_RUNNER_LABEL="$label"
  XCODE_RUNNER_RESULT_BUNDLE_PATH="$result_bundle"
  XCODE_RUNNER_LOG_PATH="$log_file"
  XCODE_RUNNER_REPORT_PREFIX="$report_prefix"
  export XCODE_RUNNER_LABEL XCODE_RUNNER_RESULT_BUNDLE_PATH XCODE_RUNNER_LOG_PATH XCODE_RUNNER_REPORT_PREFIX
}

xcode_runner_result_failed() {
  local result_path="${1:-}"
  xcode_runner_result_bundle_complete "$result_path" || return 1
  command -v xcrun >/dev/null 2>&1 || return 1
  xcrun xcresulttool get test-results summary --path "$result_path" 2>/dev/null \
    | grep -Eq '"result"[[:space:]]*:[[:space:]]*"Failed"'
}

xcode_runner_result_bundle_complete() {
  local result_path="${1:-}"
  [[ -f "$result_path/Info.plist" ]]
}

xcode_runner_log_proves_test_execution() {
  local log_file="${1:-}"
  [[ -f "$log_file" ]] || return 1
  grep -Eq \
    "Executed [1-9][0-9]* tests?|Test Case '.+' (passed|failed)|[✔✘] Test run with [1-9][0-9]* tests?" \
    "$log_file"
}

xcode_runner_call_reporter() {
  local result_bundle="$1"
  local log_file="$2"
  local exit_code="$3"
  local label="$4"
  local report_prefix="$5"
  local defer_terminal_output="${6:-false}"
  local reporter="${XCODE_RUNNER_REPORTER:-$PWD/Scripts/summarize-failures.py}"
  local reporter_status=0
  local restore_errexit=false
  local reporter_args=(
    --result-bundle "$result_bundle"
    --log "$log_file"
    --exit-code "$exit_code"
    --label "$label"
    --output-prefix "$report_prefix"
  )

  if [[ "$defer_terminal_output" == "true" ]]; then
    reporter_args+=(--defer-terminal-output)
  fi

  [[ "$-" == *e* ]] && restore_errexit=true

  if [[ -x "$reporter" ]]; then
    set +e
    "$reporter" "${reporter_args[@]}"
    reporter_status=$?
    if [[ "$restore_errexit" == "true" ]]; then set -e; else set +e; fi
  elif [[ -f "$reporter" ]]; then
    set +e
    python3 "$reporter" "${reporter_args[@]}"
    reporter_status=$?
    if [[ "$restore_errexit" == "true" ]]; then set -e; else set +e; fi
  else
    echo "Warning: failure reporter is unavailable; continuing with xcodebuild status." >&2
    reporter_status=0
  fi

  # Diagnostics are advisory. Never replace the Xcode status with a reporter
  # process status, even if a local toolchain cannot parse an xcresult.
  if [[ "$exit_code" -ne 0 && -f "$log_file" && "$defer_terminal_output" != "true" ]]; then
    echo "=== xcode-runner: raw log excerpt ($log_file) ===" >&2
    # Prefer actionable lines; fall back to the end of the quiet log so CI is
    # not blind when diagnostics misclassify benign setup noise.
    local excerpt_lines="${TRINKET_XCODE_FAILURE_LOG_LINES:-$TRINKET_XCODE_FAILURE_LOG_LINES_DEFAULT}"
    local excerpt_chars="${TRINKET_XCODE_FAILURE_LOG_LINE_CHARS:-$TRINKET_XCODE_FAILURE_LOG_LINE_CHARS_DEFAULT}"
    [[ "$excerpt_lines" =~ ^[0-9]+$ ]] || excerpt_lines="$TRINKET_XCODE_FAILURE_LOG_LINES_DEFAULT"
    [[ "$excerpt_chars" =~ ^[0-9]+$ ]] || excerpt_chars="$TRINKET_XCODE_FAILURE_LOG_LINE_CHARS_DEFAULT"
    matches="$(grep -n -E -i 'error:|fatal error:|exception|actool|ibtoold|nil object|BUILD FAILED|\*\* BUILD|\*\* TEST FAILED' "$log_file" | head -n "$excerpt_lines" || true)"
    if [[ -n "$matches" ]]; then
      printf '%s\n' "$matches" | awk -v limit="$excerpt_chars" '{ if (length($0) > limit) print substr($0, 1, limit - 1) "…"; else print }' >&2
      if [[ "$(printf '%s\n' "$matches" | wc -l | tr -d ' ')" -ge "$excerpt_lines" ]]; then
        echo "… additional matching log lines omitted by xcode-runner" >&2
      fi
    else
      tail -n "$excerpt_lines" "$log_file" | awk -v limit="$excerpt_chars" '{ if (length($0) > limit) print substr($0, 1, limit - 1) "…"; else print }' >&2 || true
    fi
    echo "=== end raw log excerpt ===" >&2
  fi
  return "$reporter_status"
}

xcode_runner_write_manifest() {
  local result_bundle="$1"
  local report_prefix="$2"
  local exit_code="$3"
  local label="$4"
  local manifest_path diagnostics_json="" result_stem

  result_stem="$(basename "$result_bundle")"
  result_stem="${result_stem%.xcresult}"
  # Result bundles are tokenized per invocation; retain that token in the
  # manifest so repeated same-label runs cannot overwrite each other's status.
  manifest_path="$(dirname "$result_bundle")/${result_stem}-invocation.json"
  if [[ -f "${report_prefix}.json" ]]; then
    diagnostics_json="${report_prefix}.json"
  fi
  mkdir -p "$(dirname "$manifest_path")"

  # Use a temporary file + replace so ci-diagnostics.sh never consumes a
  # partially-written completion record if a wrapper is interrupted.
  python3 - "$manifest_path" "$label" "$exit_code" "$result_bundle" "$diagnostics_json" <<'PY' || true
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

path, label, exit_code, result_bundle, diagnostics_json = sys.argv[1:]
payload = {
    "schema_version": 1,
    "label": label,
    "exit_code": int(exit_code),
    "status": "passed" if int(exit_code) == 0 else "failed",
    "result_bundle": result_bundle,
    "diagnostics_json": diagnostics_json,
    "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "completion_source": os.environ.get("XCODE_RUNNER_COMPLETION_SOURCE", "process-exit"),
    "test_execution_proven": os.environ.get("XCODE_RUNNER_TEST_EXECUTION_PROVEN", "false") == "true",
    "result_bundle_complete": Path(result_bundle, "Info.plist").is_file(),
}
session_id = os.environ.get("TRINKET_DIAGNOSTICS_SESSION_ID", "").strip()
if session_id:
    payload["session_id"] = session_id
target = Path(path)
temporary = target.with_name(f".{target.name}.{os.getpid()}.tmp")
temporary.write_text(json.dumps(payload, separators=(",", ":")) + "\n", encoding="utf-8")
os.replace(temporary, target)
PY
  XCODE_RUNNER_MANIFEST_PATH="$manifest_path"
  export XCODE_RUNNER_MANIFEST_PATH
}

# Hard ceiling for one xcodebuild invocation (0 disables). Covers compile stalls
# with no terminal marker. Default 20 minutes.
xcode_runner_wall_timeout_seconds() {
  printf '%s' "${TRINKET_XCODE_WALL_TIMEOUT_SECONDS:-1200}"
}

# After a terminal TEST/BUILD / XCTest outer-suite marker, kill if the raw log
# stops growing (0 disables). Targets post-result simulator-diagnostics hangs
# (Xcode can wait ~600s after suites finish before printing ** TEST SUCCEEDED **).
# Default 45 seconds — long enough for brief post-suite log/xcresult noise,
# short enough that a diagnostics hang does not dominate smoke wall-clock.
xcode_runner_idle_timeout_seconds() {
  printf '%s' "${TRINKET_XCODE_IDLE_TIMEOUT_SECONDS:-45}"
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
  [[ -f "$log_file" ]] || return 1
  # Prefer XCTest outer-suite completion over `** TEST SUCCEEDED **`:
  # Xcode often hangs ~600s collecting simulator diagnostics *after* suites
  # finish and only then prints the classic banner. Idle watchdogs must arm
  # on the earlier marker or smoke wall-clock burns the full diagnostics wait.
  # Also match Swift Testing run summaries and classic build/test banners.
  grep -Eq \
    "Test Suite '(Selected tests|All tests)' (passed|failed)|\\*\\* (TEST|BUILD) (SUCCEEDED|FAILED) \\*\\*|Testing started completed|✘ Test run with |✔ Test run with " \
    "$log_file"
}

# Infer exit status when we kill a hung post-terminal xcodebuild.
# 0 = success banner/suite, 65 = failure banner/summary, 124 = timed out with no result.
xcode_runner_infer_exit_from_log() {
  local log_file="$1"
  [[ -f "$log_file" ]] || {
    printf '124'
    return
  }
  if grep -Eq "\\*\\* (TEST|BUILD) FAILED \\*\\*|✘ Test run with |Test Suite '(Selected tests|All tests)' failed" "$log_file"; then
    printf '65'
    return
  fi
  if grep -Eq "\\*\\* (TEST|BUILD) SUCCEEDED \\*\\*|✔ Test run with |Test Suite '(Selected tests|All tests)' passed" "$log_file"; then
    printf '0'
    return
  fi
  printf '124'
}

xcode_runner_kill_tree() {
  local pid="$1"
  local child
  [[ -n "$pid" ]] || return 0
  for child in $(pgrep -P "$pid" 2>/dev/null || true); do
    xcode_runner_kill_tree "$child"
  done
  kill -TERM "$pid" 2>/dev/null || true
}

xcode_runner_force_kill_tree() {
  local pid="$1"
  local child
  [[ -n "$pid" ]] || return 0
  for child in $(pgrep -P "$pid" 2>/dev/null || true); do
    xcode_runner_force_kill_tree "$child"
  done
  kill -KILL "$pid" 2>/dev/null || true
}

# Run a command redirected to log_file, with optional wall-clock and post-terminal
# idle-log watchdogs. Echoes nothing; returns the command (or inferred) exit status.
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

  while kill -0 "$cmd_pid" 2>/dev/null; do
    sleep 1
    size="$(xcode_runner_log_byte_size "$log_file")"
    if (( size > last_size )); then
      last_size=$size
      last_growth=$SECONDS
    fi
    if [[ "$saw_terminal" == "false" ]] && xcode_runner_log_has_terminal_marker "$log_file"; then
      saw_terminal=true
      # Reset idle clock once tests/build report a terminal result so brief
      # post-result log noise does not immediately trip the watchdog.
      last_growth=$SECONDS
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

xcode_runner_run() {
  local label=""
  local result_bundle=""
  local log_file=""
  local report_prefix=""
  local quiet="${XCODE_RUNNER_QUIET:-true}"
  local defer_terminal_output="${XCODE_RUNNER_DEFER_TERMINAL_OUTPUT:-false}"
  local retry_callback=""
  local working_directory=""
  local max_attempts=1
  local command_args=()
  local attempt=1
  local xcode_exit=0
  local result_failed=false
  local restore_errexit=false
  local prepare_results_dir

  XCODE_RUNNER_COMPLETION_SOURCE="process-exit"
  XCODE_RUNNER_TEST_EXECUTION_PROVEN="false"
  export XCODE_RUNNER_COMPLETION_SOURCE XCODE_RUNNER_TEST_EXECUTION_PROVEN

  [[ "$-" == *e* ]] && restore_errexit=true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --label)
        label="$2"; shift 2
        ;;
      --result-bundle)
        result_bundle="$2"; shift 2
        ;;
      --log)
        log_file="$2"; shift 2
        ;;
      --report-prefix)
        report_prefix="$2"; shift 2
        ;;
      --quiet)
        quiet=true; shift
        ;;
      --verbose)
        quiet=false; shift
        ;;
      --defer-terminal-output)
        defer_terminal_output=true; shift
        ;;
      --retry-callback)
        retry_callback="$2"; max_attempts=2; shift 2
        ;;
      --working-directory)
        working_directory="$2"; shift 2
        ;;
      --)
        shift
        command_args=("$@")
        break
        ;;
      *)
        echo "xcode_runner_run: unknown option '$1'" >&2
        return 2
        ;;
    esac
  done

  [[ -n "$label" ]] || label="${XCODE_RUNNER_LABEL:-xcodebuild}"
  if [[ -z "$result_bundle" || -z "$log_file" || -z "$report_prefix" ]]; then
    prepare_results_dir="${RESULTS_DIR:-${DERIVED_DATA_PATH:-$PWD/.DerivedData}/TestResults}"
    if [[ -n "$result_bundle" ]]; then
      prepare_results_dir="$(dirname "$result_bundle")"
    fi
    xcode_runner_prepare "$label" "$prepare_results_dir" "$report_prefix"
    [[ -n "$result_bundle" ]] || result_bundle="$XCODE_RUNNER_RESULT_BUNDLE_PATH"
    [[ -n "$log_file" ]] || log_file="$XCODE_RUNNER_LOG_PATH"
    [[ -n "$report_prefix" ]] || report_prefix="$XCODE_RUNNER_REPORT_PREFIX"
  fi
  mkdir -p "$(dirname "$log_file")" "$(dirname "$report_prefix")"

  if [[ ${#command_args[@]} -eq 0 ]]; then
    echo "xcode_runner_run: no command supplied" >&2
    return 2
  fi

  # Scripted builds do not need the IDE index store; skip it unless the caller
  # already set COMPILER_INDEX_STORE_ENABLE explicitly. Simulator scripted
  # builds also skip code signing unless the caller set those flags.
  local cmd_name="${command_args[0]##*/}"
  local has_index_store=false
  local has_signing_allowed=false
  local has_signing_required=false
  local uses_simulator=false
  local arg
  if [[ "$cmd_name" == "xcodebuild" ]]; then
    for arg in "${command_args[@]}"; do
      case "$arg" in
        COMPILER_INDEX_STORE_ENABLE=*) has_index_store=true ;;
        CODE_SIGNING_ALLOWED=*) has_signing_allowed=true ;;
        CODE_SIGNING_REQUIRED=*) has_signing_required=true ;;
        *iphonesimulator*|*iOS\ Simulator*) uses_simulator=true ;;
      esac
    done
    if [[ "$has_index_store" == "false" ]]; then
      command_args+=("COMPILER_INDEX_STORE_ENABLE=NO")
    fi
    if [[ "$uses_simulator" == "true" ]]; then
      if [[ "$has_signing_allowed" == "false" ]]; then
        command_args+=("CODE_SIGNING_ALLOWED=NO")
      fi
      if [[ "$has_signing_required" == "false" ]]; then
        command_args+=("CODE_SIGNING_REQUIRED=NO")
      fi
    fi
  fi

  while (( attempt <= max_attempts )); do
    if [[ "$quiet" == "true" ]] && xcode_runner_watchdog_enabled; then
      set +e
      xcode_runner_execute_watched "$log_file" "$working_directory" "${command_args[@]}"
      xcode_exit=$?
      if [[ "$restore_errexit" == "true" ]]; then set -e; else set +e; fi
    elif [[ "$quiet" == "true" ]]; then
      set +e
      if [[ -n "$working_directory" ]]; then
        (cd "$working_directory" && "${command_args[@]}" >"$log_file" 2>&1)
      else
        "${command_args[@]}" >"$log_file" 2>&1
      fi
      xcode_exit=$?
      if [[ "$restore_errexit" == "true" ]]; then set -e; else set +e; fi
    elif command -v xcbeautify >/dev/null 2>&1; then
      set +e
      if [[ -n "$working_directory" ]]; then
        (cd "$working_directory" && "${command_args[@]}" 2>&1) | tee "$log_file" | xcbeautify
      else
        "${command_args[@]}" 2>&1 | tee "$log_file" | xcbeautify
      fi
      xcode_exit=${PIPESTATUS[0]}
      if [[ "$restore_errexit" == "true" ]]; then set -e; else set +e; fi
    else
      set +e
      if [[ -n "$working_directory" ]]; then
        (cd "$working_directory" && "${command_args[@]}" 2>&1) | tee "$log_file"
      else
        "${command_args[@]}" 2>&1 | tee "$log_file"
      fi
      xcode_exit=${PIPESTATUS[0]}
      if [[ "$restore_errexit" == "true" ]]; then set -e; else set +e; fi
    fi

    result_failed=false
    if xcode_runner_result_failed "$result_bundle"; then
      result_failed=true
    fi
    if [[ "$xcode_exit" -eq 0 && "$result_failed" == "true" ]]; then
      xcode_exit=1
    fi
    if xcode_runner_log_proves_test_execution "$log_file"; then
      XCODE_RUNNER_TEST_EXECUTION_PROVEN="true"
      export XCODE_RUNNER_TEST_EXECUTION_PROVEN
    fi
    if [[ "$xcode_exit" -eq 0 && "$XCODE_RUNNER_COMPLETION_SOURCE" == "watchdog-log-inference" ]]; then
      local command_action="${command_args[1]:-}"
      if [[ "$command_action" == "test" || "$command_action" == "test-without-building" ]] \
        && [[ "$XCODE_RUNNER_TEST_EXECUTION_PROVEN" != "true" ]]; then
        echo "xcode-runner: terminal suite marker did not prove that any tests executed." >&2
        xcode_exit=1
      fi
    fi
    if [[ "$xcode_exit" -eq 0 ]]; then
      # Keep a structured invocation record for CI aggregation. Diagnostics
      # are intentionally generated only for failures; a passing result bundle
      # plus this manifest is the proof of a clean invocation.
      xcode_runner_write_manifest "$result_bundle" "$report_prefix" 0 "$label"
      return 0
    fi

    if (( attempt < max_attempts )) && [[ -n "$retry_callback" ]]; then
      set +e
      "$retry_callback" "$xcode_exit" "$log_file" "$result_bundle"
      local retryable=$?
      if [[ "$restore_errexit" == "true" ]]; then set -e; else set +e; fi
      if [[ "$retryable" -eq 0 ]]; then
        echo "xcodebuild infrastructure failure; re-preparing simulator and retrying once..." >&2
        if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
          echo "::warning title=Xcode infrastructure retry::Destination or simulator service failed; retrying once."
        fi
        if declare -F ensure_test_simulator_logged >/dev/null 2>&1; then
          set +e
          ensure_test_simulator_logged force
          local sim_status=$?
          if [[ "$restore_errexit" == "true" ]]; then set -e; else set +e; fi
          if [[ "$sim_status" -eq 0 ]]; then
            if [[ -n "${SIMULATOR_DESTINATION:-}" ]]; then
              local _i
              for (( _i = 0; _i < ${#command_args[@]}; _i++ )); do
                if [[ "${command_args[$_i]}" == "-destination" && $((_i + 1)) -lt ${#command_args[@]} ]]; then
                  command_args[$((_i + 1))]="$SIMULATOR_DESTINATION"
                elif [[ "${command_args[$_i]}" == -destination=* ]]; then
                  command_args[$_i]="-destination=$SIMULATOR_DESTINATION"
                fi
              done
            fi
          fi
        fi
        rm -rf "$result_bundle"
        attempt=$((attempt + 1))
        continue
      fi
    fi
    break
  done

  # A report is produced for every failed Xcode invocation, including build
  # failures where no xcresult directory was created.
  xcode_runner_call_reporter \
    "$result_bundle" "$log_file" "$xcode_exit" "$label" "$report_prefix" "$defer_terminal_output" \
    || true
  xcode_runner_write_manifest "$result_bundle" "$report_prefix" "$xcode_exit" "$label"

  return "$xcode_exit"
}

# The helper is normally sourced. A direct invocation is useful for smoke/fake
# Xcode integration tests and intentionally does not invent a command contract.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Source this file and call xcode_runner_run; it is a shared wrapper helper." >&2
  exit 2
fi
