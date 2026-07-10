#!/usr/bin/env bash
# Classify CI outcomes without changing the pass/fail result of real tests.
set -euo pipefail

cd "$(dirname "$0")/.."
RESULTS_DIR="${1:-$PWD/.DerivedData/TestResults}"
OUTPUT_PATH="$RESULTS_DIR/ci-diagnostics.json"

mkdir -p "$RESULTS_DIR"

category="passed"
detail="No infrastructure signatures or failed test results were found."

if rg -qi 'Input required and not supplied|checksum mismatch|version mismatch|xcodegen not found' "$RESULTS_DIR" --glob '*.log' 2>/dev/null; then
  category="configuration"
  detail="A required CI input or pinned tool was unavailable or mismatched."
elif rg -qi 'Simulator boot timed out|Simulator setup failed|Unable to boot|CoreSimulator|DTServiceHub|destination.*not available|no matching destination|launchd_sim' "$RESULTS_DIR" --glob '*.log' 2>/dev/null; then
  category="simulator-infrastructure"
  detail="Simulator or destination infrastructure failed before a conclusive test result."
fi

for result in "$RESULTS_DIR"/*.xcresult; do
  [[ -d "$result" ]] || continue
  if xcrun xcresulttool get test-results summary --path "$result" 2>/dev/null | grep -Eq '"result" : "(Failed|unknown)"'; then
    category="test-regression"
    detail="At least one XCTest or Swift Testing result reported a failed or unknown result."
    break
  fi
done

python3 - "$OUTPUT_PATH" "$category" "$detail" <<'PY'
import json
import sys
from datetime import datetime, timezone

path, category, detail = sys.argv[1:]
with open(path, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "recorded_at": datetime.now(timezone.utc).isoformat(),
            "category": category,
            "detail": detail,
        },
        handle,
        separators=(",", ":"),
    )
    handle.write("\n")
PY

echo "CI diagnostic category: $category — $detail"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## CI diagnostics"
    echo
    echo "- **Category:** \`$category\`"
    echo "- **Detail:** $detail"
    if [[ -f "$RESULTS_DIR/timing-log.jsonl" ]]; then
      echo
      echo "<details><summary>Timing report</summary>"
      echo
      echo '```text'
      ./Scripts/test-timing.sh report --last 8 --top 10 || true
      echo '```'
      echo
      echo "</details>"
    fi
  } >> "$GITHUB_STEP_SUMMARY"
fi
