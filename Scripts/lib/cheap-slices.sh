#!/usr/bin/env bash

trinket_run_cheap_slices() {
  ./Scripts/check-module-boundaries.sh
  ./Scripts/check-swift-testing-migration.sh
  ./Scripts/release-notes.sh validate
  ./Scripts/check-artwork-budget.sh
}

# Keep in sync with handoff.sh run_cheap_ci_slices profiled list.
