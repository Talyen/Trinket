#!/usr/bin/env bash

# Shared xcodebuild orchestration.
#
# The runner is intentionally sourceable: the test/build wrappers retain
# ownership of their command-line contracts while this file owns log/result
# allocation, output policy, simulator retry, and failure reporting.

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
  local results_dir="${2:-${RESULTS_DIR:-$PWD/.DerivedData/TestResults}}"
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
  [[ -d "$result_path" ]] || return 1
  command -v xcrun >/dev/null 2>&1 || return 1
  xcrun xcresulttool get test-results summary --path "$result_path" 2>/dev/null \
    | grep -Eq '"result"[[:space:]]*:[[:space:]]*"Failed"'
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
  return "$reporter_status"
}

xcode_runner_write_manifest() {
  local result_bundle="$1"
  local report_prefix="$2"
  local exit_code="$3"
  local label="$4"
  local safe_label manifest_path diagnostics_json=""

  safe_label="$(xcode_runner_sanitize_label "$label")"
  manifest_path="$(dirname "$result_bundle")/${safe_label}-invocation.json"
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
      --max-attempts)
        max_attempts="$2"; shift 2
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
    prepare_results_dir="${RESULTS_DIR:-$PWD/.DerivedData/TestResults}"
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

  while (( attempt <= max_attempts )); do
    if [[ "$quiet" == "true" ]]; then
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
          if [[ "$restore_errexit" == "true" ]]; then set -e; else set +e; fi
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
