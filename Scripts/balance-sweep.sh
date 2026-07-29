#!/usr/bin/env bash
set -euo pipefail

# Headless balance sweep. Writes markdown under BalanceSweepReports/ (gitignored).
# Requires Swift toolchain (Xcode 26+ / Swift 6.2) with macOS package support.
#
# Examples:
#   ./Scripts/balance-sweep.sh
#   ./Scripts/balance-sweep.sh --battles-per-tier 100 --seed 42
#   ./Scripts/balance-sweep.sh --mode ability-contrast --battles-per-tier 200 --tiers early
#   ./Scripts/balance-sweep.sh --mode all --battles-per-tier 1000

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found. Install Xcode 26+ command-line tools to run BalanceSweepCLI." >&2
  exit 1
fi

OUTPUT_DIR="${BALANCE_SWEEP_OUTPUT_DIR:-BalanceSweepReports}"
ARGS=()
HAS_OUTPUT=0
for arg in "$@"; do
  if [[ "$arg" == "--output-dir" ]]; then
    HAS_OUTPUT=1
  fi
  ARGS+=("$arg")
done

if [[ "$HAS_OUTPUT" -eq 0 ]]; then
  ARGS+=(--output-dir "$OUTPUT_DIR")
fi

mkdir -p "$OUTPUT_DIR"

echo "BalanceSweepCLI via Packages/BattleEngine …" >&2
swift run --package-path Packages/BattleEngine BalanceSweepCLI "${ARGS[@]}"
