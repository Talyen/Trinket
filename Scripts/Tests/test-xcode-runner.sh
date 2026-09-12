#!/usr/bin/env bash
set -euo pipefail

# Small fake-Xcode integration coverage for the shared wrapper. This test does
# not require Xcode, a simulator, or the diagnostics parser.

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../lib/xcodebuild-infra.sh
source "$ROOT_DIR/Scripts/lib/xcodebuild-infra.sh"
RUNNER="$ROOT_DIR/Scripts/xcode-runner.sh"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

source "$ROOT_DIR/Scripts/lib/xcode-watchdog.sh"
python3 - "$TMP_DIR/large-terminal.log" <<'PY'
from pathlib import Path
import sys

Path(sys.argv[1]).write_text("Test Suite 'All tests' passed\n" + "test progress\n" * 100000)
PY
xcode_runner_log_has_terminal_marker "$TMP_DIR/large-terminal.log"
for failure in \
  "** TEST FAILED **" \
  "✘ Test example() recorded an issue at Example.swift:12:3: Expectation failed" \
  "✘ Suite Example failed after 1 second with 1 issue." \
  "Test Case '-[Example example]' failed (0.1 seconds)." \
  "Example.swift:12: error: XCTAssertEqual failed" \
  "Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches."; do
  printf '%s\n' "$failure" "✔ Test run with 2 tests passed after 0.1 seconds." > "$TMP_DIR/mixed-results.log"
  [[ "$(xcode_runner_infer_exit_from_log "$TMP_DIR/mixed-results.log")" == 65 ]]
done

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

cat > "$TMP_DIR/fake-slow-finalization" <<'FAKE_FINALIZATION'
#!/usr/bin/env bash
set -euo pipefail
echo "Test Suite 'Selected tests' passed."
sleep 12
echo "** TEST SUCCEEDED **"
FAKE_FINALIZATION

cat > "$TMP_DIR/fake-hang-success" <<'FAKE_HANG'
#!/usr/bin/env bash
set -euo pipefail
echo "** TEST SUCCEEDED **"
echo "Testing started completed."
echo " Executed 1 test, with 0 failures (0 unexpected) in 1.0 seconds"
# Simulate post-result xcresult/simctl hang.
while true; do sleep 60; done
FAKE_HANG

# Reproduces the real smoke hang: XCTest outer suite finishes, then xcodebuild
# idles ~600s collecting simulator diagnostics before printing ** TEST SUCCEEDED **.
cat > "$TMP_DIR/fake-hang-selected-suite" <<'FAKE_HANG_SUITE'
#!/usr/bin/env bash
set -euo pipefail
echo "Test Suite 'Selected tests' passed at 2026-08-07 12:38:46.504."
echo "	 Executed 1 test, with 0 failures (0 unexpected) in 10.489 (10.493) seconds"
while true; do sleep 60; done
FAKE_HANG_SUITE

cat > "$TMP_DIR/fake-hang-fail" <<'FAKE_HANG_FAIL'
#!/usr/bin/env bash
set -euo pipefail
echo "Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches."
echo "✔ Test run with 2 tests in 1 suite passed after 0.1 seconds."
while true; do sleep 60; done
FAKE_HANG_FAIL

cat > "$TMP_DIR/fake-hang-silent" <<'FAKE_HANG_SILENT'
#!/usr/bin/env bash
set -euo pipefail
echo "compiling..."
while true; do sleep 60; done
FAKE_HANG_SILENT

cat > "$TMP_DIR/fake-hang-zero-tests" <<'FAKE_HANG_ZERO'
#!/usr/bin/env bash
set -euo pipefail
echo "Test Suite 'Selected tests' passed at 2026-08-07 12:38:46.504."
echo " Executed 0 tests, with 0 failures (0 unexpected) in 0.0 seconds"
while true; do sleep 60; done
FAKE_HANG_ZERO

cat > "$TMP_DIR/fake-reporter" <<'FAKE_REPORTER'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "${REPORT_CAPTURE:?}"
exit 0
FAKE_REPORTER
chmod +x "$TMP_DIR/fake-slow-finalization" "$TMP_DIR/fake-xcodebuild" "$TMP_DIR/fake-reporter" \
  "$TMP_DIR/fake-hang-success" "$TMP_DIR/fake-hang-selected-suite" \
  "$TMP_DIR/fake-hang-fail" "$TMP_DIR/fake-hang-silent" "$TMP_DIR/fake-hang-zero-tests"

REPORT_CAPTURE="$TMP_DIR/result-args" XCODE_RUNNER_REPORTER="$TMP_DIR/fake-reporter" \
  bash -eu -c '
    source "$1"
    xcode_runner_prepare summary "$2"
    mkdir -p "$XCODE_RUNNER_RESULT_BUNDLE_PATH"
    touch "$XCODE_RUNNER_RESULT_BUNDLE_PATH/Info.plist"
    xcrun() { cat "$fixture"; }
    fixture="$3"
    if xcode_runner_run --label summary \
      --result-bundle "$XCODE_RUNNER_RESULT_BUNDLE_PATH" \
      --log "$XCODE_RUNNER_LOG_PATH" --report-prefix "$XCODE_RUNNER_REPORT_PREFIX" -- true; then
      echo "failed result incorrectly accepted a successful process exit" >&2
      exit 1
    else
      [[ "$?" -eq 1 ]]
    fi
  ' _ "$RUNNER" "$TMP_DIR/result-summary" "$ROOT_DIR/Scripts/Tests/Fixtures/test-summary.json"

bounded_log="$TMP_DIR/bounded.log"
for _ in $(seq 1 100); do
  printf 'Sources/VeryLong.swift:17: error: %s\n' "$(printf 'x%.0s' $(seq 1 500))" >> "$bounded_log"
done
bounded_terminal="$TMP_DIR/bounded-terminal"
bash -c '
  set -euo pipefail
  source "$1"
  xcode_runner_call_reporter "$2/missing.xcresult" "$3" 1 bounded "$2/report" true
' _ "$RUNNER" "$TMP_DIR" "$bounded_log" >"$bounded_terminal" 2>&1
bounded_matches="$(grep -c 'Sources/VeryLong.swift' "$bounded_terminal" || true)"
[[ "$bounded_matches" -le 81 ]]
awk 'length($0) <= 430' "$bounded_terminal" >/dev/null

failure_results="$TMP_DIR/failure-results"
failure_state="$TMP_DIR/failure-state"
failure_args="$TMP_DIR/failure-args"
failure_terminal="$TMP_DIR/failure-terminal"
FAKE_XCODE_STATE="$failure_state" FAKE_XCODE_MODE=fail REPORT_CAPTURE="$failure_args" \
  TRINKET_DIAGNOSTICS_SESSION_ID="fake-session" \
  TRINKET_XCODE_WALL_TIMEOUT_SECONDS=0 \
  TRINKET_XCODE_IDLE_TIMEOUT_SECONDS=0 \
  XCODE_RUNNER_REPORTER="$TMP_DIR/fake-reporter" \
  bash -c '
    set -euo pipefail
    source "$1"
    xcode_runner_prepare failure "$2"
    result="$XCODE_RUNNER_RESULT_BUNDLE_PATH"
    log="$XCODE_RUNNER_LOG_PATH"
    report="$XCODE_RUNNER_REPORT_PREFIX"
    [[ "$XCODE_RUNNER_INVOCATION_ID" == "$(basename "$result" .xcresult)" ]]
    if xcode_runner_run --label failure --result-bundle "$result" --log "$log" \
      --report-prefix "$report" --quiet --defer-terminal-output -- "$3"; then
      echo "failure command unexpectedly succeeded" >&2
      exit 1
    else
      status=$?
    fi
    [[ "$status" -eq 65 ]]
    [[ -f "$log" && "$log" == "$2/raw/"* ]]
    manifest="$(find "$(dirname "$result")" -maxdepth 1 -type f -name 'failure-*-invocation.json' | sort | tail -1)"
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
  TRINKET_XCODE_WALL_TIMEOUT_SECONDS=0 \
  TRINKET_XCODE_IDLE_TIMEOUT_SECONDS=0 \
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
    manifest="$(find "$(dirname "$XCODE_RUNNER_RESULT_BUNDLE_PATH")" -maxdepth 1 -type f -name 'retry-*-invocation.json' | sort | tail -1)"
    grep -F -- "\"status\":\"passed\"" "$manifest"
    grep -F -- "\"diagnostics_json\":\"\"" "$manifest"
  ' _ "$RUNNER" "$retry_results" "$TMP_DIR/fake-xcodebuild"

env -u TRINKET_XCODE_IDLE_TIMEOUT_SECONDS GITHUB_ACTIONS=false bash -c '
  set -euo pipefail
  source "$1"
  xcode_runner_execute_watched "$2" "" "$3"
  [[ "$XCODE_RUNNER_COMPLETION_SOURCE" == "process-exit" ]]
' _ "$RUNNER" "$TMP_DIR/finalization.log" "$TMP_DIR/fake-slow-finalization"

idle_results="$TMP_DIR/idle-results"
idle_terminal="$TMP_DIR/idle-terminal"
REPORT_CAPTURE="$TMP_DIR/idle-args" \
  TRINKET_XCODE_WALL_TIMEOUT_SECONDS=0 \
  TRINKET_XCODE_IDLE_TIMEOUT_SECONDS=2 \
  XCODE_RUNNER_REPORTER="$TMP_DIR/fake-reporter" \
  bash -c '
    set -euo pipefail
    source "$1"
    xcode_runner_prepare idle-success "$2"
    if xcode_runner_run --label idle-success \
      --result-bundle "$XCODE_RUNNER_RESULT_BUNDLE_PATH" \
      --log "$XCODE_RUNNER_LOG_PATH" \
      --report-prefix "$XCODE_RUNNER_REPORT_PREFIX" \
      --quiet -- "$3"; then
      status=0
    else
      status=$?
    fi
    [[ "$status" -eq 0 ]]
    grep -F -- "** TEST SUCCEEDED **" "$XCODE_RUNNER_LOG_PATH"
    manifest="$(find "$(dirname "$XCODE_RUNNER_RESULT_BUNDLE_PATH")" -maxdepth 1 -type f -name 'idle-success-*-invocation.json' | sort | tail -1)"
    grep -F -- "\"completion_source\":\"watchdog-log-inference\"" "$manifest"
    grep -F -- "\"test_execution_proven\":true" "$manifest"
    grep -F -- "\"result_bundle_complete\":false" "$manifest"
  ' _ "$RUNNER" "$idle_results" "$TMP_DIR/fake-hang-success" >"$idle_terminal" 2>&1
grep -F -- "killing hung command" "$idle_terminal"
grep -F -- "inferred exit 0" "$idle_terminal"

suite_idle_results="$TMP_DIR/suite-idle-results"
suite_idle_terminal="$TMP_DIR/suite-idle-terminal"
REPORT_CAPTURE="$TMP_DIR/suite-idle-args" \
  TRINKET_XCODE_WALL_TIMEOUT_SECONDS=0 \
  TRINKET_XCODE_IDLE_TIMEOUT_SECONDS=2 \
  XCODE_RUNNER_REPORTER="$TMP_DIR/fake-reporter" \
  bash -c '
    set -euo pipefail
    source "$1"
    xcode_runner_prepare idle-selected "$2"
    if xcode_runner_run --label idle-selected \
      --result-bundle "$XCODE_RUNNER_RESULT_BUNDLE_PATH" \
      --log "$XCODE_RUNNER_LOG_PATH" \
      --report-prefix "$XCODE_RUNNER_REPORT_PREFIX" \
      --quiet -- "$3"; then
      status=0
    else
      status=$?
    fi
    [[ "$status" -eq 0 ]]
    grep -F -- "Test Suite '\''Selected tests'\'' passed" "$XCODE_RUNNER_LOG_PATH"
    # Must not require the late banner — that is what the diagnostics hang delays.
    ! grep -F -- "** TEST SUCCEEDED **" "$XCODE_RUNNER_LOG_PATH"
  ' _ "$RUNNER" "$suite_idle_results" "$TMP_DIR/fake-hang-selected-suite" >"$suite_idle_terminal" 2>&1
grep -F -- "killing hung command" "$suite_idle_terminal"
grep -F -- "inferred exit 0" "$suite_idle_terminal"

zero_test_results="$TMP_DIR/zero-test-results"
zero_test_terminal="$TMP_DIR/zero-test-terminal"
TRINKET_XCODE_WALL_TIMEOUT_SECONDS=0 \
  TRINKET_XCODE_IDLE_TIMEOUT_SECONDS=2 \
  XCODE_RUNNER_REPORTER="$TMP_DIR/fake-reporter" \
  bash -c '
    set -euo pipefail
    source "$1"
    xcode_runner_prepare zero-tests "$2"
    if xcode_runner_run --label zero-tests \
      --result-bundle "$XCODE_RUNNER_RESULT_BUNDLE_PATH" \
      --log "$XCODE_RUNNER_LOG_PATH" \
      --report-prefix "$XCODE_RUNNER_REPORT_PREFIX" \
      --quiet -- "$3" test; then
      echo "zero-test watchdog result unexpectedly succeeded" >&2
      exit 1
    else
      status=$?
    fi
    [[ "$status" -eq 1 ]]
  ' _ "$RUNNER" "$zero_test_results" "$TMP_DIR/fake-hang-zero-tests" >"$zero_test_terminal" 2>&1
grep -F -- "did not prove that any tests executed" "$zero_test_terminal"

fail_idle_results="$TMP_DIR/fail-idle-results"
fail_idle_terminal="$TMP_DIR/fail-idle-terminal"
REPORT_CAPTURE="$TMP_DIR/fail-idle-args" \
  TRINKET_XCODE_WALL_TIMEOUT_SECONDS=0 \
  TRINKET_XCODE_IDLE_TIMEOUT_SECONDS=2 \
  XCODE_RUNNER_REPORTER="$TMP_DIR/fake-reporter" \
  bash -c '
    set -euo pipefail
    source "$1"
    xcode_runner_prepare idle-fail "$2"
    if xcode_runner_run --label idle-fail \
      --result-bundle "$XCODE_RUNNER_RESULT_BUNDLE_PATH" \
      --log "$XCODE_RUNNER_LOG_PATH" \
      --report-prefix "$XCODE_RUNNER_REPORT_PREFIX" \
      --quiet -- "$3"; then
      echo "idle-fail unexpectedly succeeded" >&2
      exit 1
    else
      status=$?
    fi
    [[ "$status" -eq 65 ]]
  ' _ "$RUNNER" "$fail_idle_results" "$TMP_DIR/fake-hang-fail" >"$fail_idle_terminal" 2>&1
grep -F -- "inferred exit 65" "$fail_idle_terminal"

wall_results="$TMP_DIR/wall-results"
wall_terminal="$TMP_DIR/wall-terminal"
REPORT_CAPTURE="$TMP_DIR/wall-args" \
  TRINKET_XCODE_WALL_TIMEOUT_SECONDS=2 \
  TRINKET_XCODE_IDLE_TIMEOUT_SECONDS=0 \
  XCODE_RUNNER_REPORTER="$TMP_DIR/fake-reporter" \
  bash -c '
    set -euo pipefail
    source "$1"
    xcode_runner_prepare wall "$2"
    if xcode_runner_run --label wall \
      --result-bundle "$XCODE_RUNNER_RESULT_BUNDLE_PATH" \
      --log "$XCODE_RUNNER_LOG_PATH" \
      --report-prefix "$XCODE_RUNNER_REPORT_PREFIX" \
      --quiet -- "$3"; then
      echo "wall timeout unexpectedly succeeded" >&2
      exit 1
    else
      status=$?
    fi
    [[ "$status" -eq 124 ]]
  ' _ "$RUNNER" "$wall_results" "$TMP_DIR/fake-hang-silent" >"$wall_terminal" 2>&1
grep -F -- "wall-clock" "$wall_terminal"
grep -F -- "exit 124" "$wall_terminal"

# --- bounded runner: hung helpers die at the cap, fast commands pass through ---
bounded_run_terminal="$TMP_DIR/bounded-run-terminal"
bash -c '
  set -euo pipefail
  source "$1"
  xcode_runner_run_bounded 30 true
  if xcode_runner_run_bounded 1 "$2"; then
    echo "bounded run unexpectedly succeeded" >&2
    exit 1
  fi
' _ "$RUNNER" "$TMP_DIR/fake-hang-silent" >"$bounded_run_terminal" 2>&1

# Build manifests identify compile-only proof; targeted checks use the bounded query.
bash -eu -c '
  source "$1"
  xcodebuild() { echo "** BUILD SUCCEEDED **"; }
  xcode_runner_run --label compile --result-bundle "$2/build.xcresult" \
    --log "$2/build.log" --report-prefix "$2/build-report" -- xcodebuild build
  python3 - "$XCODE_RUNNER_MANIFEST_PATH" <<"PY_MANIFEST"
import json, sys
manifest = json.load(open(sys.argv[1]))
assert manifest["action"] == "build" and manifest["exit_code"] == 0
PY_MANIFEST
  source "$3/Scripts/lib/test-helpers.sh"
  TARGETS=(ExampleTests)
  RESULT_BUNDLE_PATH="$2/complete.xcresult"
  mkdir -p "$RESULT_BUNDLE_PATH"
  touch "$RESULT_BUNDLE_PATH/Info.plist"
  xcrun() { return 99; }
  xcode_runner_run_bounded() { [[ "$1" == 60 ]] || exit 98; return 124; }
  if trinket_assert_targeted_tests_executed; then exit 97; fi
' _ "$RUNNER" "$TMP_DIR" "$ROOT_DIR"

bash -eu -c '
  source "$1"
  capture="$2/diagnostic-arguments"
  xcodebuild() { printf "%s\n" "$@" > "$capture"; }
  for scenario in test test-without-building build macos explicit; do
    action=test
    sdk=iphonesimulator
    case "$scenario" in
      test-without-building|build) action="$scenario" ;;
      macos) sdk=macosx ;;
    esac
    args=("$action" -sdk "$sdk")
    if [[ "$scenario" == explicit ]]; then args+=(-collect-test-diagnostics on-failure); fi
    xcode_runner_run --label "$scenario" --result-bundle "$2/$scenario.xcresult" \
      --log "$2/$scenario.log" --report-prefix "$2/$scenario-report" \
      -- xcodebuild "${args[@]}"
    python3 - "$capture" "$scenario" <<"PY_OPTIONS"
from pathlib import Path
import sys
args = Path(sys.argv[1]).read_text().splitlines()
scenario = sys.argv[2]
if scenario in {"build", "macos"}:
    assert "-collect-test-diagnostics" not in args, args
else:
    assert args.count("-collect-test-diagnostics") == 1, args
    assert args[args.index("-collect-test-diagnostics") + 1] == ("on-failure" if scenario == "explicit" else "never"), args
PY_OPTIONS
  done
' _ "$RUNNER" "$TMP_DIR"

# Infra retry matcher covers XCUITest launch flakes even when exit is 65.
python3 - "$ROOT_DIR" <<'PY_FILTERS'
import json
import subprocess
import sys
import tempfile

def case(identifier, result="Passed"):
    return {"nodeType": "Test Case", "nodeIdentifier": identifier, "result": result}

checks = [
    ([case("ExampleTests/testOne()")], ["ExampleTests"], True),
    ([case("ExampleTests/testOne()")], ["TrinketUITests/ExampleTests/testOne"], True),
    ([case("ExampleTests/testOne()")], ["ExampleTests", "MissingTests"], False),
    ([case("ExampleTests/testOne()")], ["ExampleTests/testOther"], False),
    ([case("ExampleTestsExtra/testOne()")], ["ExampleTests"], False),
    ([case("ExampleTests/testOne()", "Skipped")], ["ExampleTests"], False),
    ([case("ExampleTests/testOne()", "Skipped"), case("OtherTests/testOne()")], ["ExampleTests"], False),
    ([case("ExampleTests/testOne()"), case("ExampleTests/testTwo()", "Skipped")], ["ExampleTests"], True),
    ([], ["ExampleTests"], False),
]
command = '''
source "$1/Scripts/lib/test-helpers.sh"
fixture="$2"
complete="$3"
shift 3
TARGETS=("$@")
RESULT_BUNDLE_PATH=fixture
XCODEBUILD_LOG_PATH="$fixture"
xcode_runner_result_bundle_complete() { [[ "$complete" == 1 ]]; }
xcrun() { :; }
xcode_runner_run_bounded() { printf '%s' "$fixture"; }
trinket_assert_targeted_tests_executed
'''
for nodes, targets, succeeds in checks:
    payload = json.dumps({"testNodes": [{"nodeType": "Test Suite", "children": nodes}]})
    result = subprocess.run(["bash", "-eu", "-c", command, "_", sys.argv[1], payload, "1", *targets],
                            capture_output=True, text=True)
    assert (result.returncode == 0) == succeeds, (targets, nodes, result.stdout, result.stderr)
with tempfile.NamedTemporaryFile(mode="w+") as log:
    for content, targets, succeeds in [
        ("Test Case '-[TrinketUITests.ExampleTests testOne]' passed (1 seconds).", ["ExampleTests/testOne"], True),
        ("Test Case '-[TrinketUITests.ExampleTests testOne]' passed (1 seconds).", ["ExampleTests", "MissingTests"], False),
        ("Test Case '-[TrinketUITests.ExampleTests testOne]' skipped (1 seconds).", ["ExampleTests"], False),
        ("Test Case '-[TrinketUITests.ExampleTests testOne]' started.\nExecuted 1 test, with 0 failures", ["ExampleTests"], False),
    ]:
        log.seek(0)
        log.truncate()
        log.write(content)
        log.flush()
        result = subprocess.run(["bash", "-eu", "-c", command, "_", sys.argv[1], log.name, "0", *targets],
                                capture_output=True, text=True)
        assert (result.returncode == 0) == succeeds, (content, targets, result.stdout, result.stderr)
print("Targeted execution filter cases passed")
PY_FILTERS

# Evidence patterns determine classification; exit code alone must not override.
launch_log="$TMP_DIR/launch.log"
cat > "$launch_log" <<'EOF'
Failed to launch <XCUIApplicationImpl: 0x1 com.ryanmcintire.Trinket> via Xcode: Timed out while launching application via Xcode.
Failed to get background assertion for target app with pid 18060: No failure details provided
EOF
trinket_xcodebuild_log_is_infrastructure_failure 65 "$launch_log"
! trinket_xcodebuild_log_is_infrastructure_failure 65 "$TMP_DIR/missing.log"
product_log="$TMP_DIR/product.log"
echo 'XCTAssertEqual failed: ("1") is not equal to ("2")' > "$product_log"
! trinket_xcodebuild_log_is_infrastructure_failure 65 "$product_log"
! trinket_xcodebuild_log_is_infrastructure_failure 70 "$product_log"

echo "xcode-runner fake integration tests passed"
