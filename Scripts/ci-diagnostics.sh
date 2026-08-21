#!/usr/bin/env bash
# Aggregate structured diagnostics emitted by each CI test invocation.
#
# This script is intentionally read-only with respect to test output.  The
# invocation reporters own xcresult parsing on failures; this step only
# combines their JSON reports/manifests and writes the CI-level status.  It
# must never change the test command's exit status (the workflow records that
# status separately).
set -euo pipefail

cd "$(dirname "$0")/.."
MODE="aggregate"
ALL=false
if [[ "${1:-}" == "--reset" ]]; then MODE="reset"; shift; fi
if [[ "${1:-}" == "--stage-artifacts" ]]; then MODE="stage"; shift; fi
if [[ "${1:-}" == "--prune-successes" ]]; then MODE="prune"; shift; fi
if [[ "${1:-}" == "--cleanup" ]]; then MODE="cleanup"; shift; fi
if [[ "${1:-}" == "--all" ]]; then ALL=true; shift; fi
KEEP=false
if [[ "${1:-}" == "--keep" ]]; then KEEP=true; shift; fi
RESULTS_DIR="${1:-$PWD/.DerivedData/TestResults}"
OUTPUT_PATH="$RESULTS_DIR/ci-diagnostics.json"

mkdir -p "$RESULTS_DIR"

if [[ "$MODE" == "reset" ]]; then
  # DerivedData may be restored from a previous CI job.  Remove only
  # diagnostics/status artifacts; current and cached raw logs/xcresults are
  # intentionally retained for the test command and artifact upload.
  find "$RESULTS_DIR" -maxdepth 1 -type f \
    \( -name '*-diagnostics.json' -o -name '*-diagnostics.md' \
    -o -name '*-diagnostics.annotations' -o -name '*-invocation.json' \
    -o -name 'ci-diagnostics.json' \) -delete
  find "$RESULTS_DIR" -maxdepth 1 -type d -name '*-diagnostics.attachments' -prune -exec rm -rf {} +
  echo "Cleared prior CI diagnostic/status artifacts in $RESULTS_DIR"
  exit 0
fi

if [[ "$MODE" == "stage" ]]; then
  ARTIFACT_DIR="${2:-}"
  if [[ -z "$ARTIFACT_DIR" || "$ARTIFACT_DIR" == "$RESULTS_DIR" || "$ARTIFACT_DIR" == "/" ]]; then
    echo "Usage: ./Scripts/ci-diagnostics.sh --stage-artifacts <RESULTS_DIR> <ARTIFACT_DIR>" >&2
    exit 2
  fi
  CATEGORY="$(python3 - "$OUTPUT_PATH" <<'PY'
import json
import sys
from pathlib import Path

try:
    payload = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError):
    payload = {}
print(payload.get("category", "unknown"))
PY
)"
  rm -rf "$ARTIFACT_DIR"
  mkdir -p "$ARTIFACT_DIR"
  find "$RESULTS_DIR" -maxdepth 1 -type f \
    \( -name 'ci-diagnostics.json' -o -name '*-invocation.json' \
    -o -name '*-diagnostics.json' -o -name '*-diagnostics.md' \
    -o -name '*-diagnostics.annotations' -o -name 'timing-log.jsonl' \) \
    -exec cp {} "$ARTIFACT_DIR/" \;
  if [[ "$CATEGORY" != "passed" ]]; then
    [[ -d "$RESULTS_DIR/raw" ]] && cp -R "$RESULTS_DIR/raw" "$ARTIFACT_DIR/raw"
    find "$RESULTS_DIR" -maxdepth 1 -type d -name '*.xcresult' -exec cp -R {} "$ARTIFACT_DIR/" \;
    find "$RESULTS_DIR" -maxdepth 1 -type d -name '*-diagnostics.attachments' -exec cp -R {} "$ARTIFACT_DIR/" \;
    printf 'full forensic artifacts retained because category=%s\n' "$CATEGORY" > "$ARTIFACT_DIR/artifact-policy.txt"
  else
    printf 'structured artifacts only; raw logs and xcresults omitted for passing invocations\n' > "$ARTIFACT_DIR/artifact-policy.txt"
  fi
  echo "Staged CI artifacts in $ARTIFACT_DIR (category=$CATEGORY)"
  exit 0
fi

if [[ "$MODE" == "prune" ]]; then
  python3 - "$RESULTS_DIR" <<'PY'
import json
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
if not root.is_dir() or root.name != "TestResults":
    raise SystemExit("refusing to prune outside an explicit TestResults directory")
removed = 0
for manifest_path in root.glob("*-invocation.json"):
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        continue
    if manifest.get("status") != "passed" or manifest.get("exit_code") != 0:
        continue
    result_value = manifest.get("result_bundle")
    if not isinstance(result_value, str) or not result_value:
        continue
    result = Path(result_value).expanduser().resolve()
    try:
        result.relative_to(root)
    except ValueError:
        continue
    if result.is_dir():
        shutil.rmtree(result)
        removed += 1
    stem = result.name.removesuffix(".xcresult")
    raw_log = root / "raw" / f"{stem}.log"
    if raw_log.is_file():
        raw_log.unlink()
        removed += 1
    attachments = root / f"{stem}-diagnostics.attachments"
    if attachments.is_dir():
        shutil.rmtree(attachments)
        removed += 1
print(f"Pruned {removed} successful-run raw artifacts from {root}")
PY
  exit 0
fi

if [[ "$MODE" == "cleanup" ]]; then
  if [[ "$KEEP" == true ]]; then
    echo "Keeping diagnostic artifacts in $RESULTS_DIR (--keep)"
    exit 0
  fi
  python3 - "$RESULTS_DIR" <<'PY'
import json
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1]).resolve()
if root.name != "TestResults" or not root.is_dir():
    raise SystemExit("refusing to clean outside an explicit TestResults directory")

removed = 0
def remove(path: Path) -> None:
    global removed
    if path.is_dir():
        shutil.rmtree(path)
        removed += 1
    elif path.is_file():
        path.unlink()
        removed += 1

for manifest_path in root.glob("*-invocation.json"):
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        continue
    if manifest.get("status") != "passed" or manifest.get("exit_code") != 0:
        continue
    result_value = manifest.get("result_bundle")
    result = Path(result_value).expanduser() if isinstance(result_value, str) else None
    if result is not None:
        result = result.resolve()
        try:
            result.relative_to(root)
        except ValueError:
            result = None
    if result is not None:
        remove(result)
        stem = result.name.removesuffix(".xcresult")
        remove(root / "raw" / f"{stem}.log")
        remove(root / f"{stem}-diagnostics.attachments")
    report = manifest.get("diagnostics_json")
    if isinstance(report, str) and report:
        report_path = Path(report).expanduser().resolve()
        try:
            report_path.relative_to(root)
        except ValueError:
            report_path = None
        if report_path is not None:
            stem = report_path.name.removesuffix(".json")
            remove(report_path)
            remove(report_path.with_suffix(".md"))
            remove(report_path.with_suffix(".annotations"))
            remove(report_path.with_name(f"{stem}.attachments"))
    remove(manifest_path)

# A passing run has no useful historical timing record. Preserve timing on a
# failed run so the current failure remains debuggable until the next cleanup.
try:
    remaining = list(root.glob("*-invocation.json"))
except OSError:
    remaining = []
if not remaining:
    remove(root / "ci-diagnostics.json")
    remove(root / "timing-log.jsonl")
    remove(root / "raw")
print(f"Cleaned {removed} successful diagnostic artifact(s) from {root}")
PY
  exit 0
fi

if [[ "$ALL" == true ]]; then
  python3 "$(dirname "$0")/ci-diagnostics.py" --all "$RESULTS_DIR" "$OUTPUT_PATH"
else
  python3 "$(dirname "$0")/ci-diagnostics.py" "$RESULTS_DIR" "$OUTPUT_PATH"
fi

# Timing is already structured in timing-log.jsonl.  Keep this optional report
# for humans, without reparsing any xcresult bundle.
if [[ -n "${GITHUB_STEP_SUMMARY:-}" && -f "$RESULTS_DIR/timing-log.jsonl" ]]; then
  {
    echo
    echo "<details><summary>Timing report</summary>"
    echo
    echo '```text'
    ./Scripts/test-timing.sh report --last 8 --top 10 || true
    echo '```'
    echo
    echo "</details>"
  } >> "$GITHUB_STEP_SUMMARY"
fi
