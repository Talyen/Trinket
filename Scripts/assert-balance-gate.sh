#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RUNS="${BALANCE_GATE_RUNS:-15}"
SAMPLES="${BALANCE_GATE_SAMPLES:-3}"
OUTPUT="${BALANCE_GATE_OUTPUT:-$ROOT/.DerivedData/BalanceReports/ci-gate.html}"

echo "Running CI balance gate sweep..."
BALANCE_SWEEP_RUNS="$RUNS" \
BALANCE_SWEEP_SAMPLES="$SAMPLES" \
BALANCE_SWEEP_OUTPUT="$OUTPUT" \
BALANCE_SWEEP_CI_GATE=1 \
BALANCE_SWEEP_ABILITY_ANALYSIS=0 \
./Scripts/balance-sweep.sh

JSON="${OUTPUT%.html}.json"
if [[ ! -f "$JSON" ]]; then
  echo "Missing balance report JSON: $JSON" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required for assert-balance-gate.sh" >&2
  exit 1
fi

VIOLATION_COUNT="$(jq '.gateViolations | length' "$JSON")"
if [[ "$VIOLATION_COUNT" != "0" ]]; then
  echo "Balance gate failed with $VIOLATION_COUNT violation(s):" >&2
  jq '.gateViolations[] | .detail' "$JSON" >&2
  exit 1
fi

echo "Balance gate passed ($JSON)"
