#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh
trinket_prepend_pinned_tools

# shellcheck source=tool-versions.env
source Scripts/tool-versions.env
# shellcheck source=swift-source-dirs.env
source Scripts/swift-source-dirs.env
SOURCE_DIRS=("${SWIFT_SOURCE_DIRS[@]}")

trinket_require_pinned_version swiftlint "$SWIFTLINT_VERSION" version

extra_args=()
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  # Dual reporters: `xcode` keeps rule/file/line in job logs (agent-watch-ci
  # excerpts); `github-actions-logging` posts Checks annotations.
  extra_args+=(--reporter xcode --reporter github-actions-logging)
fi

LINT_TARGETS=("${SOURCE_DIRS[@]}")
PATHS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --)
      shift
      PATHS+=("$@")
      break
      ;;
    *)
      PATHS+=("$1")
      shift
      ;;
  esac
done
if (( ${#PATHS[@]} > 0 )); then
  # Explicit paths bypass SwiftLint's `excluded:` list. Drop configured
  # exclusions so path-scoped style matches full-tree behavior (DEBUG labs).
  LINT_TARGETS=()
  while IFS= read -r kept_path; do
    [[ -n "$kept_path" ]] || continue
    LINT_TARGETS+=("$kept_path")
  done < <(python3 - "$PWD" "${PATHS[@]}" <<'PY'
import fnmatch
import sys
from pathlib import Path

root = Path(sys.argv[1])
paths = sys.argv[2:]
excluded: list[str] = []
in_excluded = False
for line in (root / ".swiftlint.yml").read_text(encoding="utf-8").splitlines():
    stripped = line.strip()
    if stripped == "excluded:":
        in_excluded = True
        continue
    if in_excluded:
        if stripped.startswith("- "):
            excluded.append(stripped[2:].strip().strip("'\""))
            continue
        if stripped and not stripped.startswith("#"):
            break

for path in paths:
    normalized = path.replace("\\", "/").lstrip("./")
    skip = False
    for entry in excluded:
        entry_n = entry.replace("\\", "/").lstrip("./")
        if (
            normalized == entry_n
            or normalized.startswith(entry_n.rstrip("/") + "/")
            or fnmatch.fnmatch(normalized, entry_n)
            or fnmatch.fnmatch(normalized, entry_n.rstrip("/") + "/*")
        ):
            skip = True
            break
    if not skip:
        print(path)
PY
)
  if (( ${#LINT_TARGETS[@]} == 0 )); then
    echo "SwiftLint: all path-scoped targets are excluded; skipping."
    exit 0
  fi
fi

mkdir -p .DerivedData/swiftlint-cache

if [ ${#extra_args[@]} -gt 0 ]; then
  swiftlint lint --cache-path .DerivedData/swiftlint-cache "${extra_args[@]}" "${LINT_TARGETS[@]}"
else
  swiftlint lint --cache-path .DerivedData/swiftlint-cache "${LINT_TARGETS[@]}"
fi
