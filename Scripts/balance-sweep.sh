#!/usr/bin/env bash
set -euo pipefail

# Headless balance sweep. Writes findings markdown under BalanceSweepReports/ (gitignored).
# Requires Swift toolchain (Xcode 27+ / Swift 6.4) with macOS package support.
# Builds release by default so combat runs in optimized worker processes.
#
# Examples:
#   ./Scripts/balance-sweep.sh
#   ./Scripts/balance-sweep.sh --samples 32 --seed 42 --jobs 8
#   ./Scripts/balance-sweep.sh --mode ability-contrast --samples 200 --tiers early
#   ./Scripts/balance-sweep.sh --mode talent-contrast --samples 8 --tiers early
#   ./Scripts/balance-sweep.sh --mode all --samples 1000
#   ./Scripts/balance-sweep.sh --no-build --mode identity --samples 4  # reuse cached binary
#
# --no-build skips `swift run`'s rebuild and execs the last-built binary.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found. Install Xcode 26+ command-line tools to run BalanceSweepCLI." >&2
  exit 1
fi

OUTPUT_DIR="${BALANCE_SWEEP_OUTPUT_DIR:-BalanceSweepReports}"
ARGS=()
HAS_OUTPUT=0
NO_BUILD=0
WANT_HELP=0
for arg in "$@"; do
  if [[ "$arg" == "--output-dir" ]]; then
    HAS_OUTPUT=1
  fi
  if [[ "$arg" == "--no-build" ]]; then
    NO_BUILD=1
    continue
  fi
  if [[ "$arg" == "--help" ]]; then
    WANT_HELP=1
  fi
  ARGS+=("$arg")
done

# `--help` alone needs no sweep: prefer the cached binary so help does not
# trigger a rebuild. Falls through to the normal path when unbuilt.
if [[ "$WANT_HELP" -eq 1 && "$NO_BUILD" -eq 0 && "$HAS_OUTPUT" -eq 0 && "${#ARGS[@]}" -le 1 ]]; then
  CACHED="$ROOT/Packages/BattleEngine/.build/${BALANCE_SWEEP_CONFIGURATION:-release}/BalanceSweepCLI"
  if [[ -x "$CACHED" ]]; then
    exec "$CACHED" --help
  fi
fi

if [[ "$HAS_OUTPUT" -eq 0 ]]; then
  ARGS+=(--output-dir "$OUTPUT_DIR")
fi

mkdir -p "$OUTPUT_DIR"

CONFIGURATION="${BALANCE_SWEEP_CONFIGURATION:-release}"
if [[ "$NO_BUILD" -eq 1 ]]; then
  BIN="$ROOT/Packages/BattleEngine/.build/$CONFIGURATION/BalanceSweepCLI"
  if [[ ! -x "$BIN" ]]; then
    echo "error: --no-build given but $BIN is missing; run once without it." >&2
    exit 1
  fi
  echo "BalanceSweepCLI via cached binary ($CONFIGURATION) …" >&2
  echo "note: cached binary may predate current thresholds/flags; rebuild without --no-build if results look stale." >&2
  exec "$BIN" "${ARGS[@]}"
fi
echo "BalanceSweepCLI via Packages/BattleEngine ($CONFIGURATION) …" >&2
swift run -c "$CONFIGURATION" --package-path Packages/BattleEngine BalanceSweepCLI "${ARGS[@]}"
