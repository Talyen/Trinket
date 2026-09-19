#!/usr/bin/env bash

# Full-gate composition — single home for the ci-gate.sh default (non---fast)
# step order so the sequence is named in code instead of restated in prose
# across ci-gate.sh and Verification.md.
#
# Sourced by ci-gate.sh after Scripts/lib/tools.sh, Scripts/run-env.sh,
# Scripts/build-freshness.sh, and Scripts/lib/cheap-slices.sh (which provide
# trinket_gate_ensure_tools, trinket_run_env_init/touch_generate_stamp, and
# trinket_run_gate_slices). This file intentionally has no set -e/-u so the
# caller retains control of shell error handling. Path-scoped verification
# keeps its own plan builder (lib/classification-plan.sh); this owns the
# full-tree order only.

# Run the full local gate: pinned tools, generation, committed-output assert,
# style, script regressions, and cheap slices (style already checked).
trinket_run_full_gate() {
  trinket_gate_ensure_tools

  trinket_log_section "Generating Xcode project / catalogs"
  ./Scripts/generate.sh

  # Align with build.sh / test.sh stamp so subsequent test.sh skips a second generate.
  trinket_run_env_init
  touch_generate_stamp "$RESULTS_DIR"

  trinket_log_section "Assert generated output is committed"
  if ! ./Scripts/assert-generated-output.sh; then
    if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
      echo "::error::Generated output drifted. Run ./Scripts/generate.sh and commit Trinket.xcodeproj + Generated catalogs."
    fi
    return 1
  fi

  trinket_log_section "Style check"
  ./Scripts/test.sh style

  trinket_log_section "Script checks"
  ./Scripts/test-scripts.sh

  trinket_log_section "Cheap slices (boundaries, API bans, release notes, artwork-budget)"
  trinket_run_gate_slices --style-checked

  trinket_log_section "Gate checks passed"
}
