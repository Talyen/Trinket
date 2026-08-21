#!/usr/bin/env bash
set -euo pipefail

# Headless balance sweep. Writes findings markdown under BalanceSweepReports/ (gitignored).
# Requires Swift toolchain (Xcode 26+ / Swift 6.2) with macOS package support.
# Builds release by default so combat runs in optimized worker processes.
#
# Examples:
#   ./Scripts/balance-sweep.sh
#   ./Scripts/balance-sweep.sh --samples 32 --seed 42 --jobs 8
#   ./Scripts/balance-sweep.sh --mode ability-contrast --samples 200 --tiers early
#   ./Scripts/balance-sweep.sh --mode talent-contrast --samples 8 --tiers early
#   ./Scripts/balance-sweep.sh --mode all --samples 1000

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift not found. Install Xcode 26+ command-line tools to run BalanceSweepCLI." >&2
  exit 1
fi

OUTPUT_DIR="${BALANCE_SWEEP_OUTPUT_DIR:-BalanceSweepReports}"
EXPLICIT_OUTPUT=false
[[ -n "${BALANCE_SWEEP_OUTPUT_DIR:-}" ]] && EXPLICIT_OUTPUT=true
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

cleanup() {
  local status=$?
  if [[ "$status" -eq 0 && "$EXPLICIT_OUTPUT" != true && "${TRINKET_KEEP_REPORTS:-0}" != "1" ]]; then
    rm -rf "$OUTPUT_DIR"
  fi
  return "$status"
}
trap cleanup EXIT INT TERM

CONFIGURATION="${BALANCE_SWEEP_CONFIGURATION:-release}"
echo "BalanceSweepCLI via Packages/BattleEngine ($CONFIGURATION) …" >&2
swift run -c "$CONFIGURATION" --package-path Packages/BattleEngine BalanceSweepCLI "${ARGS[@]}"
