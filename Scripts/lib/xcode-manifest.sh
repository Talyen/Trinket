#!/usr/bin/env bash

xcode_runner_sanitize_label() {
  local value="${1:-run}"
  value="${value//[^A-Za-z0-9_.-]/_}"
  [[ -n "$value" ]] || value="run"
  printf '%s' "$value"
}

xcode_runner_token() {
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
    report_prefix="$results_dir/${safe_label}-${token}-diagnostics"
  fi

  mkdir -p "$(dirname "$report_prefix")"
  XCODE_RUNNER_LABEL="$label"
  XCODE_RUNNER_INVOCATION_ID="${safe_label}-${token}"
  XCODE_RUNNER_RESULT_BUNDLE_PATH="$result_bundle"
  XCODE_RUNNER_LOG_PATH="$log_file"
  XCODE_RUNNER_REPORT_PREFIX="$report_prefix"
  export XCODE_RUNNER_LABEL XCODE_RUNNER_INVOCATION_ID XCODE_RUNNER_RESULT_BUNDLE_PATH XCODE_RUNNER_LOG_PATH XCODE_RUNNER_REPORT_PREFIX
}

xcode_runner_result_bundle_complete() {
  local result_path="${1:-}"
  [[ -f "$result_path/Info.plist" ]]
}

xcode_runner_summary_evidence() {
  # Emit proof flags and the compact timing summary from one query.
  local result_path="${1:-}"
  local summary
  if ! xcode_runner_result_bundle_complete "$result_path" || ! command -v xcrun >/dev/null 2>&1 \
    || ! summary="$(xcode_runner_run_bounded 60 xcrun xcresulttool get test-results summary --path "$result_path" 2>/dev/null)"; then
    printf 'false false false\n'
    return 0
  fi
  printf '%s' "$summary" | python3 -c '
import json, sys
try:
    summary = json.load(sys.stdin)
except ValueError:
    summary = None
failed = known = executed = False
if isinstance(summary, dict):
    failed_count = summary.get("failedTests")
    failed = summary.get("result") == "Failed" or (type(failed_count) is int and failed_count > 0)
    keys = ("passedTests", "failedTests")
    counts = [summary.get(key, 0) for key in keys]
    known = any(key in summary for key in keys) and all(type(count) is int and count >= 0 for count in counts)
    executed = known and sum(counts) > 0
timing = {key: summary[key] for key in (
    "result", "passedTests", "failedTests", "skippedTests", "startTime", "finishTime",
) if key in summary} if isinstance(summary, dict) else None
print(*(str(value).lower() for value in (failed, known, executed)),
      json.dumps(timing, separators=(",", ":")) if timing is not None else "")
'
}

xcode_runner_log_proves_test_execution() {
  local log_file="${1:-}"
  [[ -f "$log_file" ]] || return 1
  python3 - "$log_file" <<'PY_EXECUTION'
import re, sys

with open(sys.argv[1]) as log:
    for line in log:
        # Swift Testing run totals include skips; only individual completion is proof.
        completed = re.search(r"Test Case '.+' (passed|failed)|[✔✘] Test (?!run with ).+ (passed|failed) after ", line)
        empty_parameters = re.search(r" with 0 test cases (passed|failed) after ", line)
        if completed and not empty_parameters:
            sys.exit(0)
        summary = re.search(r"Executed (\d+) tests?(?:, with (\d+) tests? skipped)?", line)
        if summary and int(summary[1]) > int(summary[2] or 0):
            sys.exit(0)
sys.exit(1)
PY_EXECUTION
}

xcode_runner_write_manifest() {
  local result_bundle="$1"
  local report_prefix="$2"
  local exit_code="$3"
  local label="$4"
  local test_summary="${5:-}"
  local manifest_path diagnostics_json="" result_stem

  result_stem="$(basename "$result_bundle")"
  result_stem="${result_stem%.xcresult}"
  manifest_path="$(dirname "$result_bundle")/${result_stem}-invocation.json"
  if [[ -f "${report_prefix}.json" ]]; then
    diagnostics_json="${report_prefix}.json"
  fi
  mkdir -p "$(dirname "$manifest_path")"

  python3 - "$manifest_path" "$label" "$exit_code" "$result_bundle" "$diagnostics_json" "$test_summary" <<'PY' || true
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

path, label, exit_code, result_bundle, diagnostics_json, test_summary = sys.argv[1:]
payload = {
    "schema_version": 1,
    "label": label,
    "action": os.environ.get("XCODE_RUNNER_ACTION", "unknown"),
    "exit_code": int(exit_code),
    "status": "passed" if int(exit_code) == 0 else "failed",
    "result_bundle": result_bundle,
    "diagnostics_json": diagnostics_json,
    "generated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "completion_source": os.environ.get("XCODE_RUNNER_COMPLETION_SOURCE", "process-exit"),
    "test_execution_proven": os.environ.get("XCODE_RUNNER_TEST_EXECUTION_PROVEN", "false") == "true",
    "result_bundle_complete": Path(result_bundle, "Info.plist").is_file(),
}
if test_summary:
    try:
        summary = json.loads(test_summary)
    except ValueError:
        summary = None
    if isinstance(summary, dict):
        payload["test_summary"] = summary
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

xcode_runner_run_bounded() {
  local cap="$1"
  shift
  local remaining=$((cap * 4))
  "$@" &
  local pid=$!
  while (( remaining > 0 )); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.25
    remaining=$((remaining - 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    xcode_runner_kill_tree "$pid"
    sleep 1
    xcode_runner_force_kill_tree "$pid"
    wait "$pid" 2>/dev/null || true
    return 124
  fi
  wait "$pid"
}
