#!/usr/bin/env bash
# Shared evidence patterns for simulator/XCUITest infrastructure failures.
# The vocabulary lives in Scripts/config/infrastructure-patterns.env so the
# bash retry/rerun matchers and the Python failure reporter classify
# identically. Do not add tokens here; extend the config file.

trinket_infrastructure_failure_pattern() {
  if [[ -z "${TRINKET_INFRASTRUCTURE_FAILURE_PATTERN:-}" ]]; then
    # shellcheck source=../config/infrastructure-patterns.env
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../config" && pwd)/infrastructure-patterns.env"
  fi
  printf '%s' "$TRINKET_INFRASTRUCTURE_FAILURE_PATTERN"
}
