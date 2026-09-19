#!/usr/bin/env bash
# Full local gate matching CI's generate, style, script, and cheap-slice jobs (no unit/smoke).
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh
# shellcheck source=run-env.sh
source Scripts/run-env.sh
# shellcheck source=build-freshness.sh
source Scripts/build-freshness.sh
# shellcheck source=lib/cheap-slices.sh
source Scripts/lib/cheap-slices.sh
# shellcheck source=lib/gate.sh
source Scripts/lib/gate.sh

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
  trinket_log_section "Cheap slices (boundaries, API bans, release notes, artwork-budget)"
  trinket_run_gate_slices
  trinket_log_section "Fast gate checks passed"
  exit 0
fi

# Full order lives in trinket_run_full_gate (lib/gate.sh); the cheap-slice
# registry (config/cheap-slices.txt) owns the slice sequence within it.
trinket_run_full_gate
