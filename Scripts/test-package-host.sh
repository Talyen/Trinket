#!/usr/bin/env bash
# Native Engine parity pilot; deliberately retains the iOS suite in CI.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  echo "Usage: $0 (native BattleEngine parity pilot; compiled checks are CI-owned)"
  exit 0
fi
if (( $# != 0 )); then echo "Unknown native pilot argument: $1" >&2; exit 2; fi
source Scripts/lib/verification-policy.sh
trinket_require_heavy_verification "Native Engine parity pilot"
source Scripts/run-env.sh
trinket_run_env_init
mkdir -p "$RESULTS_DIR"
started="$(python3 Scripts/phase-timing.py begin)"
status=0
swift test --package-path Packages/BattleEngine \
  --scratch-path "$DERIVED_DATA_PATH/host/BattleEngine" \
  --filter BattleEngineTests --xunit-output "$RESULTS_DIR/host-engine.xml" \
  >"$RESULTS_DIR/host-engine.log" 2>&1 || status=$?
python3 Scripts/phase-timing.py end host-engine "$started" BattleEngine
if (( status != 0 )); then tail -60 "$RESULTS_DIR/host-engine.log"; exit "$status"; fi
python3 - "$RESULTS_DIR/host-engine.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
cases = list(root.iter('testcase'))
if not cases or any(list(case.iter('failure')) or list(case.iter('error')) for case in cases):
    sys.exit('Native Engine pilot did not establish executed, passing coverage.')
print(f'Native Engine pilot: {len(cases)} test cases; compare identities and counts with iOS before promotion.')
PY
