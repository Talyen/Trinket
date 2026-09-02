#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=Scripts/lib/rg-check.sh
source "$(dirname "$0")/lib/rg-check.sh"

# shellcheck source=swift-source-dirs.env
source Scripts/swift-source-dirs.env

PATHS=()
if (( $# > 0 )); then
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --) shift; PATHS+=("$@"); break ;;
      -h|--help)
        cat <<'USAGE'
Usage: ./Scripts/check-comment-ban.sh [-- path...]

Fails if any Swift comment remains in authored sources except the
toolchain allowlist. Transitional hatches (Check: allow, Concurrency-Safety)
are temporarily exempt.
USAGE
        exit 0
        ;;
      *) PATHS+=("$1"); shift ;;
    esac
  done
fi

SEARCH_ROOTS=()
if (( ${#PATHS[@]} > 0 )); then
  SEARCH_ROOTS=("${PATHS[@]}")
else
  SEARCH_ROOTS=("${SWIFT_SOURCE_DIRS[@]}")
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "check-comment-ban: ripgrep (rg) not found" >&2
  exit 1
fi

while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  file="${match%%:*}"
  rest="${match#*:}"
  line_num="${rest%%:*}"
  text="${rest#*:}"
  normalized="${file//\\//}"
  if [[ "$normalized" == Packages/TrinketContent/Sources/TrinketContent/Generated/* ]]; then
    continue
  fi
  if [[ "$text" =~ //[[:space:]]*swift-tools-version: ]]; then
    continue
  fi
  if [[ "$text" =~ //[[:space:]]*swiftlint:(disable|enable) ]]; then
    continue
  fi
  if [[ "$text" =~ //[[:space:]]*swiftformat:(disable|enable) ]]; then
    continue
  fi
  if [[ "$text" =~ //[[:space:]]*Generated\ by ]]; then
    continue
  fi
  if [[ "$text" =~ (UIStyleCheck|EntropyCheck|PersistenceCheck|ConcurrencyCheck|ExclusivityCheck|ArtworkWorkingSetCheck|TestSleepCheck):[[:space:]]*allow[[:space:]]*-[[:space:]] ]]; then
    continue
  fi
  if [[ "$text" =~ Concurrency-Safety: ]]; then
    continue
  fi
  trinket_rg_violation "$file:$line_num: Comments banned — remove comment or use an allowed toolchain directive (swift-tools-version / swiftlint:disable / swiftformat:disable) — see doc-budget skill"
done < <(rg -n --with-filename --glob '*.swift' --glob '!**/Generated/**' '(^|[[:space:]])//|/\*|\*/' "${SEARCH_ROOTS[@]}" 2>/dev/null || true)

trinket_rg_report "Comment ban violations (${#violations[@]}):" "Comment ban OK." "Comment Ban"
