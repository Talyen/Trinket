#!/usr/bin/env bash
# Standalone auto-mirror: install an isolated agent build into Trinket Run.
# Extracted from handoff.sh --mirror; handoff --mirror execs this script.
# Install-only — no relaunch — so a mid-session game is not killed.
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

if [[ "$QUIET_MIRROR" != true ]]; then
  echo ""
  echo "=== Auto-mirror: ensuring Trinket.app reflects verified packages ==="
fi
env SKIP_GENERATE=1 ./Scripts/build.sh >/dev/null 2>&1 || echo "warning: auto-mirror app build failed" >&2
if [[ "$QUIET_MIRROR" != true ]]; then
  echo ""
  echo "=== Auto-mirror to Trinket Run (isolated build → human simulator) ==="
fi
# shellcheck source=lib/promote.sh
source Scripts/lib/promote.sh
trinket_promote_auto_mirror_to_run || true
