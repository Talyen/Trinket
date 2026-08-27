#!/usr/bin/env bash
# Fail-closed mechanical invariants that agents otherwise skip: BattleEngine
# entropy, test Task.sleep, persistence try?, undocumented concurrency escapes,
# file-level swiftlint:disable without a reason, and launch artwork pin release.
#
# Escape hatches (nearby line, same style as ExclusivityCheck):
#   EntropyCheck: allow - <reason>
#   TestSleepCheck: allow - <reason>
#   PersistenceCheck: allow - <reason>
#   ConcurrencyCheck: allow - <reason>
#   ArtworkWorkingSetCheck: allow - <reason>
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=swift-source-dirs.env
source ./Scripts/swift-source-dirs.env

violations=()

has_nearby_allow() {
  local file="$1"
  local line_number="$2"
  local marker="$3"
  local start=$((line_number > 4 ? line_number - 4 : 1))
  if sed -n "${start},${line_number}p" "$file" \
    | grep -Eq "^[[:space:]]*//[[:space:]]*${marker}:[[:space:]]*allow[[:space:]]*-[[:space:]]*[[:graph:]]"; then
    return 0
  fi
  return 1
}

has_nearby_concurrency_rationale() {
  local file="$1"
  local line_number="$2"
  local start=$((line_number > 4 ? line_number - 4 : 1))
  if sed -n "${start},${line_number}p" "$file" | grep -Eq 'Concurrency-Safety:'; then
    return 0
  fi
  if has_nearby_allow "$file" "$line_number" "ConcurrencyCheck"; then
    return 0
  fi
  return 1
}

scan_matches() {
  local pattern="$1"
  local glob="$2"
  shift 2
  rg -n --glob "$glob" --glob '!**/Generated/**' "$pattern" "$@" 2>/dev/null || true
}

while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  local_file="${match%%:*}"
  rest="${match#*:}"
  line="${rest%%:*}"
  text="${rest#*:}"
  if [[ "$text" =~ ^[[:space:]]*// ]]; then
    continue
  fi
  if has_nearby_allow "$local_file" "$line" "EntropyCheck"; then
    continue
  fi
  violations+=("${local_file}:${line}: unseeded Date()/UUID() in BattleEngine rule code")
done < <(
  scan_matches '\b(Date|UUID)\(\)' '*.swift' Packages/BattleEngine/Sources/BattleEngine
)

while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  local_file="${match%%:*}"
  rest="${match#*:}"
  line="${rest%%:*}"
  text="${rest#*:}"
  if [[ "$text" =~ ^[[:space:]]*// ]]; then
    continue
  fi
  if [[ "$text" == *using:* ]]; then
    continue
  fi
  if has_nearby_allow "$local_file" "$line" "EntropyCheck"; then
    continue
  fi
  violations+=("${local_file}:${line}: unseeded .random( in BattleEngine rule code (inject RNG via using:)")
done < <(
  scan_matches '\.random\(' '*.swift' Packages/BattleEngine/Sources/BattleEngine
)

while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  local_file="${match%%:*}"
  rest="${match#*:}"
  line="${rest%%:*}"
  text="${rest#*:}"
  if [[ "$text" =~ ^[[:space:]]*// ]]; then
    continue
  fi
  if [[ "$text" == *".milliseconds("* ]]; then
    continue
  fi
  if has_nearby_allow "$local_file" "$line" "TestSleepCheck"; then
    continue
  fi
  violations+=("${local_file}:${line}: Task.sleep in package tests must poll with .milliseconds or use TestSleepCheck: allow")
done < <(
  scan_matches 'Task\.sleep' '*.swift' \
    Packages/TrinketCore/Tests \
    Packages/TrinketContent/Tests \
    Packages/BattleEngine/Tests \
    Packages/TrinketPersistence/Tests \
    Packages/TrinketDesignSystem/Tests \
    Packages/TrinketFeatureSupport/Tests \
    Packages/TrinketBattleFeature/Tests \
    Packages/TrinketAppState/Tests
)

while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  local_file="${match%%:*}"
  rest="${match#*:}"
  line="${rest%%:*}"
  text="${rest#*:}"
  if [[ "$text" =~ ^[[:space:]]*// ]]; then
    continue
  fi
  if has_nearby_allow "$local_file" "$line" "PersistenceCheck"; then
    continue
  fi
  violations+=("${local_file}:${line}: try? on persistence write/open; use an explicit path or PersistenceCheck: allow")
done < <(
  scan_matches 'try\?' '*.swift' Packages/TrinketPersistence/Sources/TrinketPersistence
)

while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  local_file="${match%%:*}"
  rest="${match#*:}"
  line="${rest%%:*}"
  text="${rest#*:}"
  if [[ "$text" =~ ^[[:space:]]*// ]]; then
    continue
  fi
  if has_nearby_concurrency_rationale "$local_file" "$line"; then
    continue
  fi
  violations+=("${local_file}:${line}: @unchecked Sendable / nonisolated(unsafe) needs a nearby Concurrency-Safety: rationale")
done < <(
  scan_matches '@unchecked Sendable|nonisolated\(unsafe\)' '*.swift' \
    "${SWIFT_SOURCE_DIRS[@]}"
)

while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  local_file="${match%%:*}"
  rest="${match#*:}"
  line="${rest%%:*}"
  text="${rest#*:}"
  if [[ "$text" == *" - "* ]]; then
    continue
  fi
  violations+=("${local_file}:${line}: file-level swiftlint:disable must include ' - <reason>'")
done < <(
  rg -n --glob '*.swift' --glob '!**/Generated/**' \
    '//[[:space:]]*swiftlint:disable([^:]|$)' \
    "${SWIFT_SOURCE_DIRS[@]}" 2>/dev/null || true
)

while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  local_file="${match%%:*}"
  rest="${match#*:}"
  line="${rest%%:*}"
  text="${rest#*:}"
  if [[ "$text" =~ ^[[:space:]]*// ]]; then
    continue
  fi
  if has_nearby_allow "$local_file" "$line" "ArtworkWorkingSetCheck"; then
    continue
  fi
  violations+=("${local_file}:${line}: do not release launch artwork pins after warmup (ArtworkWorkingSetCheck)")
done < <(
  scan_matches 'releasePins' '*.swift' Trinket/App/TrinketApp.swift
)

if ((${#violations[@]} > 0)); then
  echo "Agent invariant check failed:" >&2
  printf '  %s\n' "${violations[@]}" >&2
  echo "Escape hatches: EntropyCheck / TestSleepCheck / PersistenceCheck / ConcurrencyCheck / ArtworkWorkingSetCheck: allow - <reason>." >&2
  exit 1
fi

echo "Agent invariant check passed."
