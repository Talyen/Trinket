#!/usr/bin/env bash
# Enforce AGENTS.md platform API bans without SourceKit (works on Linux CI tools).
# SwiftLint custom_rules cover the same patterns on macOS when SourceKit is available.
set -euo pipefail

cd "$(dirname "$0")/.."

violations=()

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
    violations+=("$file:$line: $reason")
  done < <(rg -n --glob '*.swift' --glob '!**/Generated/**' "$pattern" Trinket TrinketUITests Packages || true)
}

scan_pattern '\bNavigationView\b' 'Use NavigationStack instead of NavigationView'
scan_pattern '\bObservableObject\b' 'Use @Observable instead of ObservableObject'
scan_pattern '@Published\b' 'Use @Observable properties instead of @Published'
scan_pattern '@StateObject\b' 'Use @Observable + @Environment(Type.self) instead of @StateObject'
scan_pattern '@EnvironmentObject\b' 'Use @Environment(Type.self) instead of @EnvironmentObject'
scan_pattern '@ObservedObject\b' 'Use @Bindable / @Environment(Type.self) instead of @ObservedObject'
scan_pattern 'Color\s*\(\s*red\s*:' 'Use TrinketDesign.Colors / DesignColors assets via DesignAssetColors — not Color(red:green:blue:)'
scan_pattern '(^|[^A-Za-z0-9_])Color\.(red|green|blue|orange|yellow|pink|purple|mint|teal|indigo|brown|cyan|gray|grey|black|white|accentColor)\b' 'Use TrinketDesign.Colors tokens — not SwiftUI system Color.* literals'
scan_pattern '\.(foregroundStyle|tint|fill|stroke|background)\(\.(white|black|red|green|blue|orange|yellow|pink|purple|mint|teal|indigo|brown|cyan|gray|grey|accentColor)\b' 'Use TrinketDesign.Colors / Overlay tokens instead of .foregroundStyle(.white) / .fill(.red)'
scan_pattern 'Color\s*\(\s*"[^"]+"\s*,\s*bundle\s*:\s*\.main\b' 'Move named colors into DesignColors.xcassets and expose them via TrinketDesignSystem'

if (( ${#violations[@]} > 0 )); then
  echo "Platform API ban violations:" >&2
  for violation in "${violations[@]}"; do
    echo "  - $violation" >&2
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
      file=$(echo "$violation" | cut -d: -f1)
      line=$(echo "$violation" | cut -d: -f2)
      message=$(echo "$violation" | cut -d: -f3- | xargs)
      echo "::error file=$file,line=$line,title=Platform API Ban::$message"
    fi
  done
  exit 1
fi

echo "Platform API bans OK."
