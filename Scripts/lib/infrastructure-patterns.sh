#!/usr/bin/env bash
# Shared evidence patterns for simulator/XCUITest infrastructure failures.

trinket_infrastructure_failure_pattern() {
  printf '%s' 'Unable to boot|CoreSimulator|DTServiceHub|destination.*not available|no matching destination|launchd_sim|Simulator.*failed|Timed out while launching|Failed to launch|background assertion|Failed to get background assertion|Launch session|could not boot|device is not available|no devices are booted|Destination or simulator service failed|cold boot failed|simulator-infrastructure'
}
