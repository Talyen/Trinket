#!/usr/bin/env bash
# Explicit clean-build analysis of the app and its production dependencies.
set -euo pipefail

cd "$(dirname "$0")/.."
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  echo "Usage: $0 [SwiftPath ...]"
  echo "Build the app from scratch in an isolated directory and analyze unused imports."
  exit 0
fi
for path in "$@"; do
  [[ "$path" != -* && -e "$path" ]] || { echo "Expected an existing Swift file or directory: $path" >&2; exit 1; }
done

# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh
trinket_prepend_pinned_tools
# shellcheck source=tool-versions.env
source Scripts/tool-versions.env
# shellcheck source=swift-source-dirs.env
source Scripts/swift-source-dirs.env
analysis_paths=("${SWIFT_SOURCE_DIRS[@]}")
if [[ $# -gt 0 ]]; then analysis_paths=("$@"); fi
absolute_paths="$(python3 -c 'from pathlib import Path; import sys; print("\n".join(str(Path(p).resolve()) for p in sys.argv[1:]))' "${analysis_paths[@]}")"
analysis_paths=()
while IFS= read -r path; do analysis_paths+=("$path"); done <<< "$absolute_paths"

trinket_require_pinned_version swiftlint "$SWIFTLINT_VERSION" version

export TRINKET_ISOLATE=1
source Scripts/run-env.sh
source Scripts/build-freshness.sh
source Scripts/xcode-runner.sh
source Scripts/lib/app-build.sh
trinket_run_env_init
prepare_generated_inputs "$RESULTS_DIR"
analysis_dir="$(mktemp -d "$DERIVED_DATA_PATH/analyze.XXXXXX")"
trinket_set_app_xcodebuild_args "$analysis_dir"
xcode_runner_prepare analyze-build "$RESULTS_DIR"
COMBINED="$XCODE_RUNNER_LOG_PATH"
echo "Clean analyzer build: $analysis_dir"
xcode_runner_run --label analyze-build --log "$COMBINED" \
  --report-prefix "$XCODE_RUNNER_REPORT_PREFIX" --quiet -- \
  xcodebuild build "${TRINKET_APP_XCODEBUILD_ARGS[@]}"

echo "=== SwiftLint analyze (capture_variable / unused_import / unused_declaration) ==="
analyze_output="${XCODE_RUNNER_REPORT_PREFIX%-diagnostics}-analysis.log"
echo "Analysis output: $analyze_output"
analyze_status=0
swiftlint analyze --compiler-log-path "$COMBINED" --reporter xcode "${analysis_paths[@]}" 2>&1 | tee "$analyze_output" || analyze_status=$?
if (( analyze_status != 0 && analyze_status != 1 )); then
  echo "lint-analyze: swiftlint analyze errored (exit $analyze_status)." >&2
  exit "$analyze_status"
fi
if ! grep -E -q 'Done analyzing!.* in [1-9][0-9]* files?\.' "$analyze_output"; then
  echo "lint-analyze: no proven file coverage; refusing a successful result." >&2
  exit 1
fi
if grep -E -q 'unused_import' "$analyze_output"; then
  echo "lint-analyze: unused_import violations found — remove the dead imports." >&2
  exit 1
fi
rm "$analyze_output"
rm -r "$analysis_dir"
echo "lint-analyze: no unused_import violations (remaining findings advisory); passing."
exit 0
