#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -z "${TRINKET_DIAGNOSTICS_SESSION_ID:-}" ]]; then
  TRINKET_DIAGNOSTICS_SESSION_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM:-0}"
  export TRINKET_DIAGNOSTICS_SESSION_ID
fi

# Local/release confidence gate. Runs CI gate checks plus unit and UI tests.
# --mode smoke mirrors the former ci-locally.sh (gate + unit + smoke
# canary + timing reports); --mode ui (default) is the full pre-merge/release
# confidence run.
#
# Examples:
#   ./Scripts/test-deploy.sh
#   ./Scripts/test-deploy.sh --mode smoke   # optional full local confidence
#   ./Scripts/test-deploy.sh --no-build     # re-run previously built test binaries

MODE="ui"
NO_BUILD=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      if [[ $# -lt 2 ]]; then
        echo "--mode requires smoke or ui" >&2
        exit 1
      fi
      MODE="$2"
      shift 2
      case "$MODE" in
        smoke|ui) ;;
        *)
          echo "Unknown mode: $MODE"
          echo "Usage: $0 [--mode smoke|ui] [--no-build]"
          exit 1
          ;;
      esac
      ;;
    --no-build)
      NO_BUILD=true
      shift
      ;;
    *)
      echo "Unknown argument: $1"
      echo "Usage: $0 [--mode smoke|ui] [--no-build]"
      exit 1
      ;;
  esac
done

./Scripts/ci-gate.sh
# Prevent subsequent build/test wrappers from regenerating after the gate's force generate.
export SKIP_GENERATE=1

if [[ "$NO_BUILD" == "false" ]]; then
  echo ""
  echo "=== Build for testing (app + packages) ==="
  ./Scripts/build-for-testing.sh
fi

echo ""
echo "=== Unit tests ==="
./Scripts/test.sh unit --no-build

if [[ "$MODE" == "ui" ]]; then
  echo ""
  echo "=== Full UI tests ==="
  # Deliberate release-time full run: opt past test.sh's CI-owned full-suite guard.
  TRINKET_ALLOW_FULL_UI=1 ./Scripts/test.sh ui --no-build
else
  echo ""
  echo "=== Unit timing report ==="
  python3 ./Scripts/test-timing.py report --mode unit --last 1 --top 10

  echo ""
  echo "=== Smoke UI canary ==="
  ./Scripts/test.sh smoke --no-build

  echo ""
  echo "=== Smoke timing report ==="
  python3 ./Scripts/test-timing.py report --mode smoke --last 1 --top 10
fi

echo ""
echo "=== All checks passed ==="
