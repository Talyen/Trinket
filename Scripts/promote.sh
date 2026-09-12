#!/usr/bin/env bash
# Standalone auto-mirror: install an isolated agent build into Trinket Run.
# Extracted from handoff.sh --mirror; handoff --mirror execs this script.
# Install-only by default; never updates another agent simulator.
set -euo pipefail

cd "$(dirname "$0")/.."

QUIET_MIRROR=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet) QUIET_MIRROR=true; shift ;;
    --help|-h)
      echo "Usage: $0 [--quiet]"
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ "${GITHUB_ACTIONS:-}" == "true" || "${TRINKET_PROMOTE_SKIP:-0}" == "1" ]]; then
  echo "Mirror skipped by environment."
  exit 0
fi

export TRINKET_ISOLATE=1
source Scripts/run-env.sh
trinket_run_env_init
trinket_shared_sim_lease_acquire

if [[ "$QUIET_MIRROR" != true ]]; then
  echo "=== Building app for Trinket Run ==="
fi
if ! ./Scripts/build.sh >/dev/null; then
  echo "Mirror failed: app build failed; see build diagnostics above." >&2
  exit 1
fi
source Scripts/lib/promote.sh
trinket_promote_auto_mirror_to_run
