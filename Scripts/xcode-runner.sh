#!/usr/bin/env bash

XCODE_RUNNER_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config/diagnostic-limits.env
source "$XCODE_RUNNER_SCRIPT_DIR/config/diagnostic-limits.env"
# shellcheck source=lib/xcode-manifest.sh
source "$XCODE_RUNNER_SCRIPT_DIR/lib/xcode-manifest.sh"
# shellcheck source=lib/xcode-watchdog.sh
source "$XCODE_RUNNER_SCRIPT_DIR/lib/xcode-watchdog.sh"

xcode_runner_call_reporter() {
  local result_bundle="$1"
  local log_file="$2"
  local exit_code="$3"
  local label="$4"
  local report_prefix="$5"
  local defer_terminal_output="${6:-false}"
  local reporter="${XCODE_RUNNER_REPORTER:-$PWD/Scripts/failure_diagnostics.py}"
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

  if [[ "$exit_code" -ne 0 && -f "$log_file" && "$defer_terminal_output" != "true" ]]; then
    echo "=== xcode-runner: raw log excerpt ($log_file) ===" >&2
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
      xcode_runner_write_manifest "$result_bundle" "$report_prefix" 0 "$label"
      return 0
    fi

    if (( attempt < max_attempts )) && [[ -n "$retry_callback" ]]; then
      set +e
      "$retry_callback" "$xcode_exit" "$log_file" "$result_bundle"
      local retryable=$?
      if [[ "$restore_errexit" == "true" ]]; then set -e; else set +e; fi
      if [[ "$retryable" -eq 0 ]]; then
        echo "xcodebuild infrastructure failure; re-preparing simulator (erase + boot ladder) and retrying once..." >&2
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

  xcode_runner_call_reporter \
    "$result_bundle" "$log_file" "$xcode_exit" "$label" "$report_prefix" "$defer_terminal_output" \
    || true
  xcode_runner_write_manifest "$result_bundle" "$report_prefix" "$xcode_exit" "$label"

  return "$xcode_exit"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "Source this file and call xcode_runner_run; it is a shared wrapper helper." >&2
  exit 2
fi
