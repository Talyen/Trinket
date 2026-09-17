#!/usr/bin/env bash
# Full local gate matching CI's generate, style, script, and cheap-slice jobs (no unit/smoke).
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh

FAST=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fast) FAST=true ;;
    --help|-h)
      cat <<'USAGE'
Usage: ./Scripts/ci-gate.sh [--fast]

Full gate (default): generation, style, module boundaries, script regressions,
API-ban policy (incl. XCTest migration), release-note validation, and artwork budget.

--fast skips generation and style (already covered by handoff/push) and runs
only the cheap full-tree slices: module boundaries, API-ban policy,
release-note validation, and artwork budget.
USAGE
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "$FAST" == true ]]; then
  # shellcheck source=lib/cheap-slices.sh
  source Scripts/lib/cheap-slices.sh
  trinket_log_section "Cheap slices (boundaries, API bans, release notes, artwork-budget)"
  trinket_run_gate_slices
  trinket_log_section "Fast gate checks passed"
  exit 0
fi

trinket_gate_ensure_tools

trinket_log_section "Generating Xcode project / catalogs"
./Scripts/generate.sh

# Align with build.sh / test.sh stamp so subsequent test.sh skips a second generate.
# shellcheck source=run-env.sh
source ./Scripts/run-env.sh
trinket_run_env_init
# shellcheck source=build-freshness.sh
source ./Scripts/build-freshness.sh
touch_generate_stamp "$RESULTS_DIR"

trinket_log_section "Assert generated output is committed"
if ! ./Scripts/assert-generated-output.sh; then
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    echo "::error::Generated output drifted. Run ./Scripts/generate.sh and commit Trinket.xcodeproj + Generated catalogs."
  fi
  exit 1
fi

# Order: style → boundaries → script checks → API bans → release notes → artwork budget
# (CI gate.yml calls this script).
trinket_log_section "Style check"
./Scripts/test.sh style

trinket_log_section "Script checks"
./Scripts/test-scripts.sh

trinket_log_section "Cheap slices (boundaries, API bans, release notes, artwork-budget)"
# shellcheck source=lib/cheap-slices.sh
source Scripts/lib/cheap-slices.sh
trinket_run_gate_slices --style-checked

trinket_log_section "Gate checks passed"
