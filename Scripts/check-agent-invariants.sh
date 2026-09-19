#!/usr/bin/env bash
# Fail-closed mechanical invariants that agents otherwise skip: BattleEngine
# entropy, test Task.sleep, persistence try?, undocumented concurrency escapes,
# SwiftLint disables without a reason, launch artwork pin release, and stale
# package husks left by package folds.
#
# Escape hatches (nearby line, same style as ExclusivityCheck):
#   EntropyCheck: allow - <reason>
#   TestSleepCheck: allow - <reason>
#   PersistenceCheck: allow - <reason>
#   ConcurrencyCheck: allow - <reason>
#   ArtworkWorkingSetCheck: allow - <reason>
set -euo pipefail

# shellcheck source=Scripts/lib/rg-check.sh
source "$(dirname "$0")/lib/rg-check.sh"

# shellcheck source=format-dirs.env
source ./Scripts/format-dirs.env

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  echo "Usage: ./Scripts/check-agent-invariants.sh"
  echo "Fail on skipped mechanical invariants (entropy, test sleep, persistence try?, concurrency escapes)."
  exit 0
fi

TRINKET_RG_BULLET="  "

has_nearby_allow() {
  trinket_rg_has_nearby_allow "$1" "$2" "$3"
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
  # --with-filename: ripgrep omits the file prefix for explicit single-file
  # inputs (e.g. Trinket/App/TrinketApp.swift below); without it the
  # file:line:text parse misreads the line number and the rule silently passes.
  trinket_rg_scan --with-filename -n --glob "$glob" --glob '!**/Generated/**' "$pattern" "$@"
}

scan_matches '\b(Date|UUID)\(\)' '*.swift' Packages/BattleEngine/Sources/BattleEngine
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
  trinket_rg_violation "${local_file}:${line}: unseeded Date()/UUID() in BattleEngine rule code"
done <<< "$TRINKET_RG_MATCHES"

scan_matches '\.random\(' '*.swift' Packages/BattleEngine/Sources/BattleEngine
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
  trinket_rg_violation "${local_file}:${line}: unseeded .random( in BattleEngine rule code (inject RNG via using:)"
done <<< "$TRINKET_RG_MATCHES"

scan_matches 'Task\.sleep' '*.swift' \
    Packages/TrinketCore/Tests \
    Packages/TrinketContent/Tests \
    Packages/BattleEngine/Tests \
    Packages/TrinketPersistence/Tests \
    Packages/TrinketDesignSystem/Tests \
    Packages/TrinketFeatureSupport/Tests \
    Packages/TrinketBattleFeature/Tests \
    Packages/TrinketAppState/Tests
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
  trinket_rg_violation "${local_file}:${line}: Task.sleep in package tests must poll with .milliseconds or use TestSleepCheck: allow"
done <<< "$TRINKET_RG_MATCHES"

scan_matches 'try\?' '*.swift' Packages/TrinketPersistence/Sources/TrinketPersistence
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
  trinket_rg_violation "${local_file}:${line}: try? on persistence write/open; use an explicit path or PersistenceCheck: allow"
done <<< "$TRINKET_RG_MATCHES"

scan_matches '@unchecked Sendable|nonisolated\(unsafe\)' '*.swift' \
    "${SWIFT_SOURCE_DIRS[@]}"
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
  trinket_rg_violation "${local_file}:${line}: @unchecked Sendable / nonisolated(unsafe) needs a nearby Concurrency-Safety: rationale"
done <<< "$TRINKET_RG_MATCHES"

policy_matches="$(python3 Scripts/internal/swift_policy.py swiftlint-reasons "${SWIFT_SOURCE_DIRS[@]}")"
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  trinket_rg_violation "$match"
done <<< "$policy_matches"

scan_matches 'releasePins' '*.swift' Trinket/App/TrinketApp.swift
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
  trinket_rg_violation "${local_file}:${line}: do not release launch artwork pins after warmup (ArtworkWorkingSetCheck)"
done <<< "$TRINKET_RG_MATCHES"

# A folded package deletes its Package.swift and Sources but leaves ignored
# build output (Packages/<name>/.build, build/) that plain `git status` never
# surfaces. Flag husks with neither manifest nor sources; a missing manifest
# beside live Sources already fails the build loudly elsewhere.
for tenant in Packages/*/; do
  if [[ ! -f "${tenant}Package.swift" && ! -d "${tenant}Sources" ]]; then
    trinket_rg_violation "${tenant}: package husk without Package.swift or Sources (remove the stale fold leftover)"
  fi
done

trinket_rg_report "Agent invariant check failed:" "Agent invariant check passed." "" \
  "Escape hatches: EntropyCheck / TestSleepCheck / PersistenceCheck / ConcurrencyCheck / ArtworkWorkingSetCheck: allow - <reason>."
