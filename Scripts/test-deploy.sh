#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=Scripts/lib/args.sh
source Scripts/lib/args.sh
trinket_ensure_diagnostics_session

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
TEST_DEPLOY_USAGE="Usage: $0 [--mode smoke|ui] [--no-build]"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      echo "$TEST_DEPLOY_USAGE"
      echo "Pre-release deploy verification (release.sh calls this)."
      exit 0
      ;;
    --mode)
      if [[ $# -lt 2 ]]; then
        trinket_die "--mode requires smoke or ui" "$TEST_DEPLOY_USAGE"
      fi
      MODE="$2"
      shift 2
      case "$MODE" in
        smoke|ui) ;;
        *)
          trinket_die "Unknown mode: $MODE" "$TEST_DEPLOY_USAGE"
          ;;
      esac
      ;;
    --no-build)
      NO_BUILD=true
      shift
      ;;
    --)
      shift
      trinket_die "Unexpected argument: ${1:-}" "$TEST_DEPLOY_USAGE"
      ;;
    *)
      trinket_die "Unknown argument: $1" "$TEST_DEPLOY_USAGE"
      ;;
  esac
done

./Scripts/ci-gate.sh
# Prevent subsequent build/test wrappers from regenerating after the gate's force generate.
export SKIP_GENERATE=1

if [[ "$NO_BUILD" == "false" ]]; then
  echo ""
  trinket_log_section "Build for testing (app + packages)"
  ./Scripts/build-for-testing.sh
fi

echo ""
trinket_log_section "Unit tests"
./Scripts/test.sh unit --no-build

if [[ "$MODE" == "ui" ]]; then
  echo ""
  trinket_log_section "Additional UI journeys (FullUI plan; smoke runs in main CI)"
  # Deliberate release-time full run: opt past test.sh's CI-owned full-suite guard.
  TRINKET_ALLOW_FULL_UI=1 ./Scripts/test.sh ui --no-build
else
  echo ""
  trinket_log_section "Smoke UI canary"
  ./Scripts/test.sh smoke --no-build

  echo ""
  trinket_log_section "Smoke timing report"
  python3 ./Scripts/test-timing.py report --mode smoke --last 1 --top 10
fi

echo ""
trinket_log_section "All checks passed"
