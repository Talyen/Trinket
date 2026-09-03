#!/usr/bin/env bash
# CI blocking SwiftLint analyzer pass for dead code (unused_import).
# Requires an xcodebuild compiler log from build-for-testing. Do not add this
# to handoff.sh or test.sh style — it needs the shared CI build index/log.
# tests.yml runs this as a blocking job after build, off the test critical path.
# Only unused_import fails the run; capture_variable and unused_declaration
# findings stay advisory noise in the log.
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh
trinket_prepend_pinned_tools
# shellcheck source=tool-versions.env
source Scripts/tool-versions.env
# shellcheck source=swift-source-dirs.env
source Scripts/swift-source-dirs.env

trinket_require_pinned_version swiftlint "$SWIFTLINT_VERSION" version

RESULTS_DIR="${RESULTS_DIR:-${DERIVED_DATA_PATH:-$PWD/.DerivedData}/TestResults}"
RAW_DIR="$RESULTS_DIR/raw"
COMBINED="$RESULTS_DIR/compiler-analyze.log"

if [[ ! -d "$RAW_DIR" ]]; then
  echo "lint-analyze: no compiler logs at $RAW_DIR." >&2
  echo "Hint: Generate compiler logs first via './Scripts/build-for-testing.sh --app-only' before running analyzer passes." >&2
  exit 1
fi

shopt -s nullglob
app_logs=("$RAW_DIR"/build-app-*.log)
if ((${#app_logs[@]} > 0)); then
  logs=("${app_logs[@]}")
else
  logs=("$RAW_DIR"/*.log)
fi
shopt -u nullglob
if ((${#logs[@]} == 0)); then
  echo "lint-analyze: no *.log files under $RAW_DIR." >&2
  exit 1
fi

cat "${logs[@]}" > "$COMBINED"
if ! grep -E -q 'swift(c|-frontend)' "$COMBINED"; then
  echo "lint-analyze: combined log has no Swift compiler invocations." >&2
  exit 1
fi

# xcode reporter only: github-actions-logging floods Checks with unused_import
# findings, and that annotation volume plus cache save overflows the build
# job's wall clock.
extra_args=()
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  extra_args+=(--reporter xcode)
fi

echo "=== SwiftLint analyze (capture_variable / unused_import / unused_declaration) ==="
analyze_output="$(mktemp)"
analyze_status=0
if [ ${#extra_args[@]} -gt 0 ]; then
  swiftlint analyze --compiler-log-path "$COMBINED" "${extra_args[@]}" "${SWIFT_SOURCE_DIRS[@]}" 2>&1 | tee "$analyze_output" || analyze_status=$?
else
  swiftlint analyze --compiler-log-path "$COMBINED" "${SWIFT_SOURCE_DIRS[@]}" 2>&1 | tee "$analyze_output" || analyze_status=$?
fi
if (( analyze_status != 0 && analyze_status != 1 )); then
  echo "lint-analyze: swiftlint analyze errored (exit $analyze_status)." >&2
  rm -f "$analyze_output"
  exit "$analyze_status"
fi
if grep -E -q 'unused_import' "$analyze_output"; then
  echo "lint-analyze: unused_import violations found — remove the dead imports." >&2
  rm -f "$analyze_output"
  exit 1
fi
rm -f "$analyze_output"
echo "lint-analyze: no unused_import violations (remaining findings advisory); passing."
exit 0
