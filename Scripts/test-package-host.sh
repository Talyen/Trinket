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
  --filter BattleEngineTests \
  >"$RESULTS_DIR/host-engine.log" 2>&1 || status=$?
python3 Scripts/phase-timing.py end host-engine "$started" BattleEngine
if (( status != 0 )); then tail -60 "$RESULTS_DIR/host-engine.log"; exit "$status"; fi
python3 - "$RESULTS_DIR/host-engine.log" "$RESULTS_DIR/host-engine.json" <<'PY'
import json
from pathlib import Path
import re
import sys
text = Path(sys.argv[1]).read_text()
verdicts = re.findall(r"^✔ Test run with (\d+) tests in (\d+) suites passed after ([0-9.]+) seconds\.$", text, re.M)
if len(verdicts) != 1 or int(verdicts[0][0]) == 0 or re.search(r"^✘ (?:Test|Suite)", text, re.M):
    sys.exit('Native Engine pilot did not establish executed, passing Swift Testing coverage.')
tests, suites, seconds = verdicts[0]
payload = {'passed': int(tests), 'suites': int(suites), 'test_seconds': float(seconds),
           'source': 'successful-process-and-swift-testing-verdict', 'log': sys.argv[1]}
Path(sys.argv[2]).write_text(json.dumps(payload) + "\n")
print(f'Native Engine pilot: {tests} tests in {suites} suites passed; retain the iOS comparator until parity review.')
PY
