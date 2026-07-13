#!/usr/bin/env bash
set -euo pipefail

# Small fake-Xcode integration coverage for the shared wrapper. This test does
# not require Xcode, a simulator, or the diagnostics parser.

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
RUNNER="$ROOT_DIR/Scripts/xcode-runner.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/fake-xcodebuild" <<'FAKE_XCODE'
#!/usr/bin/env bash
set -euo pipefail
state="${FAKE_XCODE_STATE:?}"
count=0
[[ -f "$state" ]] && count="$(<"$state")"
count=$((count + 1))
printf '%s' "$count" > "$state"
if [[ "${FAKE_XCODE_MODE:-fail}" == "retry" && "$count" -eq 1 ]]; then
  echo "Unable to boot simulator" >&2
  exit 70
fi
if [[ "${FAKE_XCODE_MODE:-fail}" == "fail" ]]; then
  echo "error: fake test failure" >&2
  exit 65
fi
exit 0
FAKE_XCODE

cat > "$TMP_DIR/fake-reporter" <<'FAKE_REPORTER'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "${REPORT_CAPTURE:?}"
exit 0
FAKE_REPORTER
chmod +x "$TMP_DIR/fake-xcodebuild" "$TMP_DIR/fake-reporter"

failure_results="$TMP_DIR/failure-results"
failure_state="$TMP_DIR/failure-state"
failure_args="$TMP_DIR/failure-args"
failure_terminal="$TMP_DIR/failure-terminal"
FAKE_XCODE_STATE="$failure_state" FAKE_XCODE_MODE=fail REPORT_CAPTURE="$failure_args" \
  TRINKET_DIAGNOSTICS_SESSION_ID="fake-session" \
  XCODE_RUNNER_REPORTER="$TMP_DIR/fake-reporter" \
  bash -c '
    set -euo pipefail
    source "$1"
    xcode_runner_prepare failure "$2"
    result="$XCODE_RUNNER_RESULT_BUNDLE_PATH"
    log="$XCODE_RUNNER_LOG_PATH"
    report="$XCODE_RUNNER_REPORT_PREFIX"
    if xcode_runner_run --label failure --result-bundle "$result" --log "$log" \
      --report-prefix "$report" --quiet --defer-terminal-output -- "$3"; then
      echo "failure command unexpectedly succeeded" >&2
      exit 1
    else
      status=$?
    fi
    [[ "$status" -eq 65 ]]
    [[ -f "$log" && "$log" == "$2/raw/"* ]]
    manifest="$(dirname "$result")/failure-invocation.json"
    [[ -f "$manifest" ]]
    grep -F -- "\"status\":\"failed\"" "$manifest"
    grep -F -- "\"session_id\":\"fake-session\"" "$manifest"
    grep -F -- "--result-bundle $result" "$REPORT_CAPTURE"
    grep -F -- "--exit-code 65" "$REPORT_CAPTURE"
    grep -F -- "--defer-terminal-output" "$REPORT_CAPTURE"
  ' _ "$RUNNER" "$failure_results" "$TMP_DIR/fake-xcodebuild" >"$failure_terminal" 2>&1
! grep -F -- "error: fake test failure" "$failure_terminal"

retry_results="$TMP_DIR/retry-results"
retry_state="$TMP_DIR/retry-state"
FAKE_XCODE_STATE="$retry_state" FAKE_XCODE_MODE=retry \
  XCODE_RUNNER_REPORTER="$TMP_DIR/fake-reporter" \
  bash -c '
    set -euo pipefail
    source "$1"
    ensure_test_simulator_logged() { :; }
    retryable() { [[ "$1" -eq 70 ]]; }
    xcode_runner_prepare retry "$2"
    xcode_runner_run --label retry --result-bundle "$XCODE_RUNNER_RESULT_BUNDLE_PATH" \
      --log "$XCODE_RUNNER_LOG_PATH" --report-prefix "$XCODE_RUNNER_REPORT_PREFIX" \
      --quiet --retry-callback retryable -- "$3"
    [[ "$(<"$FAKE_XCODE_STATE")" -eq 2 ]]
    grep -F -- "\"status\":\"passed\"" "$(dirname "$XCODE_RUNNER_RESULT_BUNDLE_PATH")/retry-invocation.json"
    grep -F -- "\"diagnostics_json\":\"\"" "$(dirname "$XCODE_RUNNER_RESULT_BUNDLE_PATH")/retry-invocation.json"
  ' _ "$RUNNER" "$retry_results" "$TMP_DIR/fake-xcodebuild"

echo "xcode-runner fake integration tests passed"
