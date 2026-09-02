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

xcode_runner_result_failed() {
  local result_path="${1:-}"
  xcode_runner_result_bundle_complete "$result_path" || return 1
  command -v xcrun >/dev/null 2>&1 || return 1
  local summary
  summary="$(xcode_runner_run_bounded 60 xcrun xcresulttool get test-results summary --path "$result_path" 2>/dev/null)" || return 1
  printf '%s' "$summary" | grep -Eq '"result"[[:space:]]*:[[:space:]]*"Failed"'
}

xcode_runner_log_proves_test_execution() {
  local log_file="${1:-}"
  [[ -f "$log_file" ]] || return 1
  grep -Eq \
    "Executed [1-9][0-9]* tests?|Test Case '.+' (passed|failed)|[✔✘] Test run with [1-9][0-9]* tests?" \
    "$log_file"
}

xcode_runner_write_manifest() {
  local result_bundle="$1"
  local report_prefix="$2"
  local exit_code="$3"
  local label="$4"
  local manifest_path diagnostics_json="" result_stem

  result_stem="$(basename "$result_bundle")"
  result_stem="${result_stem%.xcresult}"
  manifest_path="$(dirname "$result_bundle")/${result_stem}-invocation.json"
  if [[ -f "${report_prefix}.json" ]]; then
    diagnostics_json="${report_prefix}.json"
  fi
  mkdir -p "$(dirname "$manifest_path")"

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

xcode_runner_run_bounded() {
  local cap="$1"
  shift
  local remaining=$((cap * 4))
  "$@" >/dev/null 2>&1 &
  local pid=$!
  while (( remaining > 0 )); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.25
    remaining=$((remaining - 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    xcode_runner_kill_tree "$pid"
    wait "$pid" 2>/dev/null || true
    return 124
  fi
  wait "$pid"
}
