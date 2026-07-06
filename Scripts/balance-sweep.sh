#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RUNS="${BALANCE_SWEEP_RUNS:-20}"
SAMPLES="${BALANCE_SWEEP_SAMPLES:-5}"
OUTPUT="${BALANCE_SWEEP_OUTPUT:-$ROOT/.DerivedData/BalanceReports/latest.html}"
TIERS="${BALANCE_SWEEP_TIERS:-early,middle,lateGame}"
SMOKE="${BALANCE_SWEEP_SMOKE:-0}"
CI_GATE="${BALANCE_SWEEP_CI_GATE:-0}"
STAGE_WEIGHTED="${BALANCE_SWEEP_STAGE_WEIGHTED:-0}"
LOADOUT_MODE="${BALANCE_SWEEP_LOADOUT_MODE:-realistic}"
ABILITY_ANALYSIS="${BALANCE_SWEEP_ABILITY_ANALYSIS:-0}"

mkdir -p "$(dirname "$OUTPUT")"

ARGS=(
  --runs "$RUNS"
  --samples "$SAMPLES"
  --output "$OUTPUT"
  --tiers "$TIERS"
  --loadout-mode "$LOADOUT_MODE"
)

if [[ "$SMOKE" == "1" ]]; then
  ARGS+=(--smoke)
fi

if [[ "$CI_GATE" == "1" ]]; then
  ARGS+=(--ci-gate)
fi

if [[ "$STAGE_WEIGHTED" == "1" ]]; then
  ARGS+=(--stage-weighted)
fi

if [[ "$ABILITY_ANALYSIS" == "0" ]]; then
  ARGS+=(--no-ability-analysis)
fi

echo "Running balance sweep..."
echo "  runs:           $RUNS"
echo "  samples:        $SAMPLES"
echo "  tiers:          $TIERS"
echo "  output:         $OUTPUT"
echo "  stage-weighted: $STAGE_WEIGHTED"
echo "  loadout-mode:   $LOADOUT_MODE"
echo "  ci-gate:        $CI_GATE"

cd "$ROOT/Packages/BattleEngine"
swift run -c release BalanceSweepCLI "${ARGS[@]}"

echo ""
echo "Report written to: $OUTPUT"
