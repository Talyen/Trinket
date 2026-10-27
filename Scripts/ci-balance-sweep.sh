#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mode="${BALANCE_MODE:-identity}"
tier="${BALANCE_TIER:-all}"
samples="${BALANCE_SAMPLES:-}"
seed="${BALANCE_SEED:-}"

case "$mode" in
  identity|ability-contrast|affix-contrast|talent-contrast|mode-progression|all) ;;
  *) echo "error: invalid balance mode" >&2; exit 2 ;;
esac
case "$tier" in
  all|early|middle|lateGame) ;;
  *) echo "error: invalid balance tier" >&2; exit 2 ;;
esac
if [[ -n "$samples" ]] && { [[ ! "$samples" =~ ^[1-9][0-9]{0,2}$ ]] || (( samples > 512 )); }; then
  echo "error: samples must be an integer from 1 to 512" >&2
  exit 2
fi
if [[ -n "$seed" ]] && { [[ ! "$seed" =~ ^(0|[1-9][0-9]{0,9})$ ]] || (( seed > 4294967295 )); }; then
  echo "error: seed must be an integer from 0 to 4294967295" >&2
  exit 2
fi

mkdir -p .DerivedData/BalanceSweepResults
output_dir="$(mktemp -d .DerivedData/BalanceSweepResults/run.XXXXXXXX)"
args=(--mode "$mode" --jobs 2 --output-dir "$output_dir")
[[ "$tier" == all ]] || args+=(--tiers "$tier")
[[ -z "$samples" ]] || args+=(--samples "$samples")
[[ -z "$seed" ]] || args+=(--seed "$seed")

{
  printf 'Revision: %s\nMode: %s\nTier: %s\nSamples: %s\nSeed: %s\nJobs: 2\n' \
    "$(git rev-parse HEAD)" "$mode" "$tier" "${samples:-CLI default}" "${seed:-CLI default}"
  swift --version
} > "$output_dir/run-info.txt"

./Scripts/balance-sweep.sh "${args[@]}"
shopt -s nullglob
briefs=("$output_dir"/*.md)
reports=("$output_dir"/*.json)
if (( ${#briefs[@]} == 0 || ${#reports[@]} == 0 )); then
  echo "error: balance sweep completed without both a findings brief and JSON report" >&2
  exit 1
fi
