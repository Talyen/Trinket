#!/usr/bin/env bash
# CI-only advisory SwiftLint analyzer pass (unused_import / unused_declaration).
# Requires an xcodebuild compiler log from build-for-testing. Do not add this
# to handoff.sh or test.sh style — it needs the shared CI build index/log.
# restore-and-build runs this with continue-on-error until the first green baseline.
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
  echo "lint-analyze: no compiler logs at $RAW_DIR (CI build log required)." >&2
  exit 1
fi

shopt -s nullglob
logs=("$RAW_DIR"/*.log)
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

extra_args=()
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  extra_args+=(--reporter xcode --reporter github-actions-logging)
fi

echo "=== SwiftLint analyze (unused_import / unused_declaration) ==="
swiftlint analyze --compiler-log-path "$COMBINED" "${extra_args[@]}" "${SWIFT_SOURCE_DIRS[@]}"
