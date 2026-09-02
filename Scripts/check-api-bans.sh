#!/usr/bin/env bash
# Single ban table for legacy API usage. Merges check-platform-api-bans.sh
# (legacy observation/navigation APIs) and check-swift-testing-migration.sh
# (XCTest outside TrinketUITests). SwiftLint custom_rules cover the same
# platform patterns when SourceKit is available.
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=lib/rg-check.sh
source Scripts/lib/rg-check.sh

# Match whole identifiers / attributes; skip comments by scanning code-ish lines lightly.
scan_pattern() {
  local pattern="$1"
  local reason="$2"
  while IFS= read -r match; do
    [[ -z "$match" ]] && continue
    local file line
    file="${match%%:*}"
    rest="${match#*:}"
    line="${rest%%:*}"
    text="${rest#*:}"
    # Ignore comment-only lines. UIStyleCheck is owned by check-ui-style.py and
    # must not silence NavigationView / Observation bans here.
    if [[ "$text" =~ ^[[:space:]]*// ]]; then
      continue
    fi
    trinket_rg_violation "$file:$line: $reason"
  done < <(rg -n --glob '*.swift' --glob '!**/Generated/**' "$pattern" Trinket TrinketUITests Packages || true)
}

scan_pattern '\bNavigationView\b' 'Use NavigationStack instead of NavigationView'
scan_pattern '\bObservableObject\b' 'Use @Observable instead of ObservableObject'
scan_pattern '@Published\b' 'Use @Observable properties instead of @Published'
scan_pattern '@StateObject\b' 'Use @Observable + @Environment(Type.self) instead of @StateObject'
scan_pattern '@EnvironmentObject\b' 'Use @Environment(Type.self) instead of @EnvironmentObject'
scan_pattern '@ObservedObject\b' 'Use @Bindable / @Environment(Type.self) instead of @ObservedObject'

while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  file="${match%%:*}"
  rest="${match#*:}"
  line="${rest%%:*}"
  if [[ "$file" == *TrinketUITests/* ]]; then
    continue
  fi
  trinket_rg_violation "$file:$line: Use Swift Testing instead of XCTest outside TrinketUITests"
done < <(rg -n 'import XCTest|XCTestCase|XCTAssert|XCTFail|XCTUnwrap' Packages --glob '*Tests/**/*.swift' --glob '!**/TrinketUITests/**' 2>/dev/null || true)

trinket_rg_report "API ban violations:" "Platform API bans OK." "API Ban" \
  "Swift Testing migration gate: OK (no XCTest imports in unit targets)"
echo "Swift Testing migration gate: OK (no XCTest imports in unit targets)"
