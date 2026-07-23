#!/usr/bin/env bash
# Shared matcher for xcodebuild failures that should get one simulator re-prep retry.
# Sourced by Scripts/test.sh; covered by Scripts/Tests/test-asset-hash-sort-locale.sh.
#
# shellcheck shell=bash

trinket_xcodebuild_log_is_infrastructure_failure() {
  local exit_code="$1"
  local log_file="$2"

  [[ "$exit_code" -eq 70 ]] && return 0
  [[ -f "$log_file" ]] || return 1

  # Match CoreSimulator / destination failures and XCUITest launch flakes that often
  # still produce an xcresult (so callers must not gate on missing result bundles).
  rg -qi \
    'Unable to boot|CoreSimulator|DTServiceHub|destination.*not available|no matching destination|launchd_sim|Simulator.*failed|Timed out while launching|Failed to launch|background assertion|Failed to get background assertion|Launch session|could not boot|device is not available|no devices are booted' \
    "$log_file"
}
