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
# The production scanner revisits a bounded overlap after each read. A small
# split log never crosses that offset and cannot protect against lost markers.
python3 - "$TMP_DIR/split-terminal.log" <<'PY_SPLIT'
from pathlib import Path
import sys
Path(sys.argv[1]).write_text("compiling...\n" * 1000 + "Test Suite 'Selected ")
PY_SPLIT
split_offset="$(xcode_runner_log_byte_size "$TMP_DIR/split-terminal.log")"
if xcode_runner_scan_terminal_marker_from "$TMP_DIR/split-terminal.log" 0; then
  echo "Partial terminal marker incorrectly accepted" >&2
  exit 1
fi
printf "tests' passed.\nExecuted 1 test, with 0 failures\n" >> "$TMP_DIR/split-terminal.log"
xcode_runner_scan_terminal_marker_from "$TMP_DIR/split-terminal.log" "$split_offset"

# Keep the long finalization-grace regression without twelve seconds of real
# waiting. Only the clock/process observation is simulated; the watchdog loop
# must let an action finalize beyond the former ten-second idle cutoff.
bash -eu -c '
  source "$1/Scripts/lib/xcode-watchdog.sh"
  unset TRINKET_XCODE_IDLE_TIMEOUT_SECONDS TRINKET_CI_DEADLINE_EPOCH
  export TRINKET_XCODE_WALL_TIMEOUT_SECONDS=0
  finalization_log="$2"
  SECONDS=0
  sleep() { SECONDS=$((SECONDS + $1)); }
  kill() {
    if [[ "$1" != -0 ]]; then
      echo "Watchdog killed an action during its finalization grace" >&2
      exit 1
    fi
    printf "Test Suite '\''Selected tests'\'' passed.\nExecuted 1 test, with 0 failures\n" > "$finalization_log"
    (( SECONDS < 12 ))
  }
  xcode_runner_execute_watched "$finalization_log" "" true
  [[ "$XCODE_RUNNER_COMPLETION_SOURCE" == process-exit ]]
' _ "$ROOT_DIR" "$TMP_DIR/finalization-grace.log"

for failure in \
  "** TEST FAILED **" \
  "✘ Test example() recorded an issue at Example.swift:12:3: Expectation failed" \
  "✘ Suite Example failed after 1 second with 1 issue." \
  "Test Case '-[Example example]' failed (0.1 seconds)." \
  "Example.swift:12: error: XCTAssertEqual failed" \
  "Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches."; do
  printf '%s\n' "$failure" "✔ Test run with 2 tests passed after 0.1 seconds." "** TEST SUCCEEDED **" > "$TMP_DIR/mixed-results.log"
  [[ "$(xcode_runner_infer_exit_from_log "$TMP_DIR/mixed-results.log")" == 65 ]]
done

# Product failures must veto launch retries, including mixed Swift/XCTest logs.
for failure in \
  "Example.swift:12: error: XCTAssertEqual failed" \
  "Ability.swift:42:2: error: failed to launch macro plugin" \
  "Shader.metal:42: error: cannot find type in scope" \
  "✘ Test example() recorded an issue at Example.swift:12:3: Expectation failed" \
  "✘ Suite Example failed after 1 second with 1 issue." \
  "Test Case '-[Example example]' failed (0.1 seconds)."; do
  printf '%s\n' "Unable to boot simulator" "$failure" > "$TMP_DIR/mixed-infra.log"
  if trinket_xcodebuild_log_is_infrastructure_failure 65 "$TMP_DIR/mixed-infra.log"; then
    echo "Product failure incorrectly classified as launch infrastructure: $failure" >&2
    exit 1
  fi
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

# Each mode has isolated logs, reports, and process trees. Real waits exercise
# the watchdog; concurrent cases keep those waits off the suite's critical path.
cat > "$TMP_DIR/fake-watched-command" <<'FAKE_WATCHED'
#!/usr/bin/env bash
set -euo pipefail
case "$WATCHDOG_CASE" in
  finalization)
    echo "Test Suite 'Selected tests' passed."
    echo "Executed 1 test, with 0 failures"
    sleep 2
    echo "** TEST SUCCEEDED **"
    exit 0 ;;
  success)
    echo "** TEST SUCCEEDED **"
    echo " Executed 1 test, with 0 failures (0 unexpected) in 1.0 seconds" ;;
  selected|zero|zero-options)
    echo "Test Suite 'Selected tests' passed at 2026-08-07 12:38:46.504."
    count=1
    [[ "$WATCHDOG_CASE" != zero && "$WATCHDOG_CASE" != zero-options ]] || count=0
    echo " Executed $count tests, with 0 failures (0 unexpected) in 1.0 seconds" ;;
  mixed-active)
    echo "Test Suite 'Selected tests' passed."
    echo "Executed 0 tests, with 0 failures"
    sleep 2
    echo "◇ Test run started."
    echo "◇ Test slowButActive() started."
    sleep 4
    echo "✔ Test slowButActive() passed after 4 seconds."
    echo "✔ Test run with 1 test passed after 4 seconds."
    echo "** TEST SUCCEEDED **"
    exit 0 ;;
  mixed-incomplete)
    echo "Test Suite 'All tests' passed."
    echo "Executed 1 test, with 0 failures"
    echo "◇ Test run started."
    echo "◇ Test neverFinishes() started." ;;
  swift-summary)
    echo "✔ Test run with 1 test passed after 0.1 seconds." ;;
  failure)
    echo "Restarting after unexpected exit, crash, or test timeout; summary will include totals from previous launches."
    echo "✔ Test run with 2 tests in 1 suite passed after 0.1 seconds." ;;
  late-failure)
    echo "** TEST SUCCEEDED **"
    sleep 1
    echo "Example.swift:12: error: XCTAssertEqual failed" ;;
  growing)
    while true; do echo "compiling..."; sleep 0.2; done ;;
  silent|verbose-silent) echo "compiling..." ;;
esac
while true; do sleep 60; done
FAKE_WATCHED

cat > "$TMP_DIR/fake-reporter" <<'FAKE_REPORTER'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "${REPORT_CAPTURE:?}"
exit 0
FAKE_REPORTER
chmod +x "$TMP_DIR/fake-watched-command" "$TMP_DIR/fake-xcodebuild" "$TMP_DIR/fake-reporter"

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
python3 - "$bounded_log" <<'PY_LOG'
from pathlib import Path
import sys

Path(sys.argv[1]).write_text(("Sources/VeryLong.swift:17: error: " + "x" * 500 + "\n") * 100)
PY_LOG
bounded_terminal="$TMP_DIR/bounded-terminal"
bash -c '
  set -euo pipefail
  source "$1"
  xcode_runner_call_reporter "$2/missing.xcresult" "$3" 1 bounded "$2/report" true
' _ "$RUNNER" "$TMP_DIR" "$bounded_log" >"$bounded_terminal" 2>&1
bounded_matches="$(grep -c 'Sources/VeryLong.swift' "$bounded_terminal" || true)"
[[ "$bounded_matches" -le 81 ]]
[[ "$bounded_matches" -gt 0 ]]
awk 'length($0) > 430 { exit 1 }' "$bounded_terminal"

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

# Recovery failure preserves the original diagnostics and never retries a stale UDID.
FAKE_XCODE_STATE="$TMP_DIR/recovery-failure-state" FAKE_XCODE_MODE=retry \
  REPORT_CAPTURE="$TMP_DIR/recovery-failure-report" \
  TRINKET_XCODE_WALL_TIMEOUT_SECONDS=0 TRINKET_XCODE_IDLE_TIMEOUT_SECONDS=0 \
  XCODE_RUNNER_REPORTER="$TMP_DIR/fake-reporter" \
  bash -eu -c '
    source "$1"
    ensure_test_simulator_logged() { return 42; }
    retryable() { [[ "$1" -eq 70 ]]; }
    mkdir -p "$2/original.xcresult"
    touch "$2/original.xcresult/preserved"
    status=0
    xcode_runner_run --label recovery-failure --result-bundle "$2/original.xcresult" \
      --log "$2/failed.log" --report-prefix "$2/report" \
      --retry-callback retryable -- "$3" || status=$?
    [[ "$status" -eq 70 && "$(<"$FAKE_XCODE_STATE")" -eq 1 ]]
    [[ -f "$2/original.xcresult/preserved" ]]
    grep -q "Unable to boot simulator" "$2/failed.log"
  ' _ "$RUNNER" "$TMP_DIR/recovery-failure" "$TMP_DIR/fake-xcodebuild"

run_watchdog_case() (
  mode="$1"
  results="$TMP_DIR/watchdog-$mode"
  mkdir -p "$results"
  export WATCHDOG_CASE="$mode"
  export REPORT_CAPTURE="$results/reporter-args"
  export XCODE_RUNNER_REPORTER="$TMP_DIR/fake-reporter"
  export TRINKET_XCODE_WALL_TIMEOUT_SECONDS=0
  export TRINKET_XCODE_IDLE_TIMEOUT_SECONDS=2
  expected=0
  completion=watchdog-log-inference
  case "$mode" in
    finalization)
      unset TRINKET_XCODE_IDLE_TIMEOUT_SECONDS
      completion=process-exit ;;
    mixed-active)
      export TRINKET_XCODE_WALL_TIMEOUT_SECONDS=15
      export TRINKET_XCODE_IDLE_TIMEOUT_SECONDS=3
      completion=process-exit ;;
    mixed-incomplete)
      export TRINKET_XCODE_WALL_TIMEOUT_SECONDS=3
      expected=124
      completion=process-exit ;;
    selected|zero|zero-options|swift-summary)
      expected=124
      completion=process-exit ;;
    failure|late-failure) expected=65 ;;
    silent|verbose-silent|growing)
      export TRINKET_XCODE_WALL_TIMEOUT_SECONDS=2
      export TRINKET_XCODE_IDLE_TIMEOUT_SECONDS=0
      expected=124
      completion=process-exit ;;
  esac
  source "$RUNNER"
  command_args=("$TMP_DIR/fake-watched-command" test)
  if [[ "$mode" == zero-options ]]; then
    xcodebuild() { "$TMP_DIR/fake-watched-command" "$@"; }
    command_args=(xcodebuild -project Fixture.xcodeproj -sdk iphonesimulator test)
  fi
  xcode_runner_prepare "$mode" "$results"
  status=0
  verbosity=--quiet
  [[ "$mode" != verbose-silent ]] || verbosity=--verbose
  xcode_runner_run --label "$mode" \
    --result-bundle "$XCODE_RUNNER_RESULT_BUNDLE_PATH" \
    --log "$XCODE_RUNNER_LOG_PATH" --report-prefix "$XCODE_RUNNER_REPORT_PREFIX" \
    "$verbosity" -- "${command_args[@]}" || status=$?
  [[ "$status" == "$expected" ]] || return 1
  python3 - "$XCODE_RUNNER_MANIFEST_PATH" "$status" "$completion" "$mode" <<'PY_MANIFEST' || return 1
import json, sys
manifest = json.load(open(sys.argv[1]))
assert manifest["exit_code"] == int(sys.argv[2]), manifest
assert manifest["completion_source"] == sys.argv[3], manifest
if sys.argv[4] in {"success", "selected", "mixed-incomplete"}:
    assert manifest["test_execution_proven"] and not manifest["result_bundle_complete"], manifest
PY_MANIFEST
  case "$mode" in
    selected) ! grep -F -- "** TEST SUCCEEDED **" "$XCODE_RUNNER_LOG_PATH" || return 1 ;;
    zero|zero-options|mixed-incomplete|swift-summary)
      grep -F -- "treating as timeout (exit 124)" "$results/terminal.log" || return 1 ;;
    late-failure) grep -F -- "XCTAssertEqual failed" "$XCODE_RUNNER_LOG_PATH" || return 1 ;;
  esac
)

watchdog_cases=(finalization success selected zero zero-options mixed-active mixed-incomplete swift-summary failure late-failure silent verbose-silent growing)
watchdog_pids=()
for mode in "${watchdog_cases[@]}"; do
  mkdir -p "$TMP_DIR/watchdog-$mode"
  run_watchdog_case "$mode" >"$TMP_DIR/watchdog-$mode/terminal.log" 2>&1 &
  watchdog_pids+=("$!")
done
watchdog_failed=0
for index in "${!watchdog_cases[@]}"; do
  mode="${watchdog_cases[$index]}"
  if wait "${watchdog_pids[$index]}"; then
    echo "Watchdog $mode passed"
  else
    cat "$TMP_DIR/watchdog-$mode/terminal.log" >&2
    echo "Watchdog $mode failed" >&2
    watchdog_failed=1
  fi
done
[[ "$watchdog_failed" == 0 ]] || exit 1

# A failed first attempt must not supply execution proof for an empty retry.
bash -eu -c '
  source "$1"
  attempts=0
  xcode_runner_execute_watched() {
    attempts=$((attempts + 1))
    XCODE_RUNNER_COMPLETION_SOURCE=watchdog-log-inference
    if [[ "$attempts" == 1 ]]; then
      echo "Executed 1 test, with 0 failures" > "$1"
      return 70
    fi
    echo "Test Suite '\''Selected tests'\'' passed" > "$1"
    return 0
  }
  ensure_test_simulator_logged() { :; }
  retryable() { [[ "$1" == 70 ]]; }
  status=0
  xcode_runner_run --label empty-retry --result-bundle "$2/retry.xcresult" \
    --log "$2/retry.log" --report-prefix "$2/retry-report" \
    --retry-callback retryable -- xcodebuild test || status=$?
  [[ "$attempts" == 2 && "$status" == 1 ]]
  python3 - "$XCODE_RUNNER_MANIFEST_PATH" <<"PY_MANIFEST"
import json, sys
manifest = json.load(open(sys.argv[1]))
assert manifest["exit_code"] == 1 and not manifest["test_execution_proven"], manifest
PY_MANIFEST
' _ "$RUNNER" "$TMP_DIR/empty-retry"

# --- bounded runner: hung helpers die at the cap, fast commands pass through ---
bounded_run_terminal="$TMP_DIR/bounded-run-terminal"
WATCHDOG_CASE=silent bash -c '
  set -euo pipefail
  source "$1"
  xcode_runner_run_bounded 30 true
  if xcode_runner_run_bounded 1 "$2"; then
    echo "bounded run unexpectedly succeeded" >&2
    exit 1
  fi
' _ "$RUNNER" "$TMP_DIR/fake-watched-command" >"$bounded_run_terminal" 2>&1

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

TRINKET_XCODE_WALL_TIMEOUT_SECONDS=0 TRINKET_XCODE_IDLE_TIMEOUT_SECONDS=0 bash -eu -c '
  source "$1"
  capture="$2/diagnostic-arguments"
  xcodebuild() {
    printf "%s\n" "$@" > "$capture"
    case "$1" in test|test-without-building) echo "Executed 1 test, with 0 failures" ;; esac
  }
  source "$3/Scripts/lib/app-build.sh"
  for scenario in test test-without-building build macos explicit app-build device-build; do
    action=test
    sdk=iphonesimulator
    case "$scenario" in
      test-without-building|build) action="$scenario" ;;
      macos) sdk=macosx ;;
    esac
    args=("$action" -sdk "$sdk")
    if [[ "$scenario" == app-build || "$scenario" == device-build ]]; then
      destination="generic/platform=iOS Simulator"
      if [[ "$scenario" == device-build ]]; then sdk=iphoneos; destination="generic/platform=iOS"; fi
      trinket_set_app_xcodebuild_args "$2/app-build" "$sdk" "$destination"
      args=(build "${TRINKET_APP_XCODEBUILD_ARGS[@]}")
    fi
    if [[ "$scenario" == explicit ]]; then args+=(-collect-test-diagnostics on-failure); fi
    xcode_runner_run --label "$scenario" --result-bundle "$2/$scenario.xcresult" \
      --log "$2/$scenario.log" --report-prefix "$2/$scenario-report" \
      -- xcodebuild "${args[@]}"
    python3 - "$capture" "$scenario" <<"PY_OPTIONS"
from pathlib import Path
import sys
args = Path(sys.argv[1]).read_text().splitlines()
scenario = sys.argv[2]
if scenario in {"build", "macos", "app-build", "device-build"}:
    assert "-collect-test-diagnostics" not in args, args
else:
    assert args.count("-collect-test-diagnostics") == 1, args
    assert args[args.index("-collect-test-diagnostics") + 1] == ("on-failure" if scenario == "explicit" else "never"), args
if scenario == "app-build":
    assert "CODE_SIGNING_ALLOWED=YES" in args and "CODE_SIGNING_ALLOWED=NO" not in args, args
    assert "CODE_SIGN_IDENTITY=-" in args, args
elif scenario == "device-build":
    assert not any(arg.startswith("CODE_SIGNING_") or arg.startswith("CODE_SIGN_IDENTITY=") for arg in args), args
PY_OPTIONS
  done
' _ "$RUNNER" "$TMP_DIR" "$ROOT_DIR"


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
