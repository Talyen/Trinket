#!/usr/bin/env bash
# Shared matcher for xcodebuild failures that should get one simulator re-prep retry.
# Sourced by Scripts/test.sh; covered by Scripts/Tests/test-asset-hash-sort-locale.sh.
#
# shellcheck shell=bash
# shellcheck source=infrastructure-patterns.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/infrastructure-patterns.sh"

trinket_xcodebuild_log_is_infrastructure_failure() {
  local _exit_code="$1"
  local log_file="$2"

  [[ -f "$log_file" ]] || return 1

  # Evidence patterns determine classification; the exit code must not override
  # explicit configuration or product-test failures.
  rg -qi "$(trinket_infrastructure_failure_pattern)" "$log_file"
}
