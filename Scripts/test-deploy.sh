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
COMPILE_ONLY=false
TEST_DEPLOY_USAGE="Usage: $0 [--mode smoke|ui] [--no-build] [--compile-only]"
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
    --compile-only)
      COMPILE_ONLY=true
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

source Scripts/lib/verification-policy.sh
trinket_require_heavy_verification "Deploy test suites" || exit $?

verification_args=(--mode "$MODE")
[[ "$NO_BUILD" != true ]] || verification_args+=(--no-build)
[[ "$COMPILE_ONLY" != true ]] || verification_args+=(--compile-only)
exec python3 Scripts/deploy-verification.py "${verification_args[@]}"
