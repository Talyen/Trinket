#!/usr/bin/env bash

trinket_record_timing() {
  if [[ "${TRINKET_RECORD_TIMING:-1}" == "0" ]]; then
    return 0
  fi
  local timing_args=()
  if xcode_runner_result_bundle_complete "$RESULT_BUNDLE_PATH"; then
    timing_args+=(--xcresult "$RESULT_BUNDLE_PATH")
  else
    if [[ -d "$RESULT_BUNDLE_PATH" ]]; then
      echo "Result bundle did not finalize; recording wall-only timing for $MODE." >&2
    fi
    timing_args+=(--no-xcresult)
  fi
  local record_args=(--mode "$MODE" --run "$XCODE_RUNNER_INVOCATION_ID" --wall "$TEST_WALL_SECONDS" "${timing_args[@]}")
  if [[ "$NO_BUILD" == "true" ]]; then
    record_args+=(--no-build)
  fi
  if [[ ${#TARGETS[@]} -gt 0 ]]; then
    record_args+=("${TARGETS[@]}")
  fi
  if ! python3 ./Scripts/test-timing.py record "${record_args[@]}"; then
    echo "Warning: failed to record timing for $MODE" >&2
  fi
}

trinket_assert_no_build_is_fresh() {
  echo "Running without building. This only reruns the previously built '$RUN_FINGERPRINT' test binary."
  local built_app="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/Trinket.app"
  if [[ ! -d "$built_app" ]]; then
    echo "Built app is missing from DerivedData. Run without --no-build first." >&2
    return 1
  fi
  assert_no_build_inputs_are_fresh "$BUILD_STAMP" "$RUN_FINGERPRINT"
}

trinket_assert_targeted_tests_executed() {
  [[ ${#TARGETS[@]} -gt 0 ]] || return 0
  local tests_json="" tests_log=""
  if xcode_runner_result_bundle_complete "$RESULT_BUNDLE_PATH"; then
    command -v xcrun >/dev/null 2>&1 || return 1
    tests_json="$(xcode_runner_run_bounded 60 xcrun xcresulttool get test-results tests --path "$RESULT_BUNDLE_PATH" --compact 2>/dev/null || true)"
    if [[ -z "$tests_json" ]]; then
      echo "Targeted test result bundle could not be read; refusing a false-green result." >&2
      return 1
    fi
  else
    tests_log="$XCODEBUILD_LOG_PATH"
    echo "Result export incomplete; verifying each requested filter from terminal test-case records."
  fi
  python3 - "$tests_json" "$tests_log" "${TARGETS[@]}" <<'PY_TESTS'
import json
import re
import sys

def normalized(identifier):
    return identifier.removeprefix("TrinketUITests/").removesuffix("()")

def cases(nodes):
    for node in nodes:
        if node.get("nodeType") == "Test Case":
            yield normalized(node.get("nodeIdentifier", "")), node.get("result", "Unknown")
        yield from cases(node.get("children", []))

try:
    if sys.argv[2]:
        with open(sys.argv[2]) as log:
            completions = [match.groups() for line in log if (match := re.match(
                r"\s*Test Case '-\[(?:TrinketUITests\.)?(\w+) ([^\]]+)\]' (passed|failed|skipped)\b", line
            ))]
        tests = [(normalized(f"{suite}/{method}"), result.capitalize()) for suite, method, result in completions]
    else:
        tests = list(cases(json.loads(sys.argv[1])["testNodes"]))
except (OSError, ValueError, KeyError, TypeError, AttributeError):
    sys.exit("Targeted test results could not be decoded.")

missing = []
matched = []
for target in sys.argv[3:]:
    target = normalized(target)
    selected = [(identifier, result) for identifier, result in tests
                if target == "TrinketUITests" or identifier == target or identifier.startswith(target + "/")]
    if not selected:
        missing.append(target)
    matched.extend(selected)
if missing:
    sys.exit("Requested test filters absent from results: " + ", ".join(missing))
if not any(result in {"Passed", "Failed"} for _, result in matched):
    sys.exit("Targeted test filters executed zero tests (empty or all skipped).")
for identifier, result in tests:
    if result == "Skipped":
        print("Skipped: " + identifier + " (see test diagnostics for the reason)")
PY_TESTS
}
