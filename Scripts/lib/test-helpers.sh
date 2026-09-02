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
  if ! ./Scripts/test-timing.sh record "${record_args[@]}"; then
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
  if ! xcode_runner_result_bundle_complete "$RESULT_BUNDLE_PATH"; then
    if xcode_runner_log_proves_test_execution "$XCODEBUILD_LOG_PATH"; then
      return 0
    fi
    echo "Targeted test result bundle is incomplete and the log proves no test execution." >&2
    return 1
  fi
  command -v xcrun >/dev/null 2>&1 || return 1
  local summary_json
  summary_json="$(xcrun xcresulttool get test-results summary --path "$RESULT_BUNDLE_PATH" --compact 2>/dev/null || true)"
  if [[ -z "$summary_json" ]]; then
    echo "Targeted test result bundle could not be read; refusing a false-green result." >&2
    return 1
  fi
  if ! python3 - "$summary_json" <<'PY'
import json
import sys
def number(value):
    if isinstance(value, dict) and "_value" in value:
        value = value["_value"]
    if isinstance(value, bool):
        return 0
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0
try:
    payload = json.loads(sys.argv[1])
except json.JSONDecodeError:
    raise SystemExit(1)
total = sum(number(payload.get(key)) for key in ("passedTests", "failedTests", "skippedTests"))
if total == 0:
    total = number(payload.get("totalTests"))
raise SystemExit(0 if total > 0 else 1)
PY
  then
    echo "Targeted test filter executed zero tests; refusing a false-green result." >&2
    return 1
  fi
}

trinket_run_package_tests() {
  local xcodebuild_action="$1"
  local packages=("${TRINKET_TEST_PACKAGES[@]}")
  local failed=0
  local build_seconds=0
  local test_seconds=0
  if [[ "$xcodebuild_action" != "test-without-building" ]]; then
    SECONDS=0
    echo "Building package tests in parallel..."
    if ! ./Scripts/test-package.sh --build-for-testing "${packages[@]}"; then
      build_seconds=$SECONDS
      TEST_WALL_SECONDS=$((TEST_WALL_SECONDS + build_seconds))
      return 1
    fi
    build_seconds=$SECONDS
  fi
  SECONDS=0
  local -a package_test_args=(--no-build --destination "$SIMULATOR_DESTINATION")
  if [[ "$QUIET" == "true" ]]; then
    package_test_args+=(--quiet)
  else
    package_test_args+=(--verbose)
  fi
  echo "Running package tests in parallel..."
  if ! ./Scripts/test-package.sh "${package_test_args[@]}" "${packages[@]}"; then
    failed=1
  fi
  test_seconds=$SECONDS
  TEST_WALL_SECONDS=$((TEST_WALL_SECONDS + build_seconds + test_seconds))
  return "$failed"
}
