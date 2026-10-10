#!/usr/bin/env bash
# Native pure-logic verification; iOS comparators remain in manual/nightly CI.
set -euo pipefail
cd "$(dirname "$0")/.."
compare=false
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  echo "Usage: $0 [--compare-ios] [BattleEngine | TrinketCore ...]"
  exit 0
fi
if [[ "${1:-}" == --compare-ios ]]; then compare=true; shift; fi
if (( $# == 0 )); then set -- BattleEngine; fi
for package in "$@"; do
  case "$package" in BattleEngine|TrinketCore) ;; *) echo "Unsupported native package: $package" >&2; exit 2 ;; esac
done
source Scripts/lib/verification-policy.sh
trinket_require_heavy_verification "Native package verification"
source Scripts/build-freshness.sh
source Scripts/run-env.sh
trinket_run_env_init
mkdir -p "$RESULTS_DIR/raw"
for package in "$@"; do
  prefix="$RESULTS_DIR/native-$package"
  data="$RESULTS_DIR/raw/native-$package"
  sources=(Packages/TrinketCore)
  if [[ "$package" == BattleEngine ]]; then sources+=(Packages/BattleEngine Packages/TrinketContent); fi
  source_commit="$(git rev-parse HEAD)"
  snapshot="$(generation_input_snapshot --build-inputs "${sources[@]}")"
  started="$(python3 Scripts/phase-timing.py begin)"
  status=0
  swift test --jobs 2 --package-path "Packages/$package" --scratch-path "$DERIVED_DATA_PATH/host/$package" \
    --filter "^${package}Tests[.]" --event-stream-version 0 --event-stream-output-path "$data.events.jsonl" \
    >"$RESULTS_DIR/raw/native-$package.log" 2>&1 || status=$?
  if (( status == 0 )); then
    swift test --jobs 2 --package-path "Packages/$package" --scratch-path "$DERIVED_DATA_PATH/host/$package" \
      --filter "^${package}Tests[.]" list --skip-build >"$data.catalog" 2>>"$RESULTS_DIR/raw/native-$package.log" || status=$?
  fi
  if [[ "$source_commit" != "$(git rev-parse HEAD)" || "$snapshot" != "$(generation_input_snapshot --build-inputs "${sources[@]}")" ]]; then
    echo "Native package inputs changed during verification." >&2
    status=1
  fi
  python3 Scripts/phase-timing.py end native-test "$started" "$package"
  python3 Scripts/native-test-results.py record "$package" "$data.events.jsonl" "$data.catalog" \
    "$RESULTS_DIR/raw/native-$package.log" "$prefix-diagnostics.json" --exit-code "$status"
  if [[ "$compare" == true ]]; then
    python3 Scripts/native-test-results.py compare "$prefix-diagnostics.json" "$RESULTS_DIR/timing-log.jsonl" "$prefix-parity.json"
  fi
done
