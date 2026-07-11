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
    # Ignore comment-only lines.
    if [[ "$text" =~ ^[[:space:]]*// ]]; then
      continue
    fi
    violations+=("$file:$line: $reason")
  done < <(rg -n --glob '*.swift' --glob '!**/Generated/**' "$pattern" Trinket TrinketTests TrinketUITests Packages || true)
}

scan_pattern '\bNavigationView\b' 'Use NavigationStack instead of NavigationView'
scan_pattern '\bObservableObject\b' 'Use @Observable instead of ObservableObject'
scan_pattern '@Published\b' 'Use @Observable properties instead of @Published'
scan_pattern '@StateObject\b' 'Use @Observable + @Environment(Type.self) instead of @StateObject'
scan_pattern '@EnvironmentObject\b' 'Use @Environment(Type.self) instead of @EnvironmentObject'
scan_pattern '@ObservedObject\b' 'Use @Bindable / @Environment(Type.self) instead of @ObservedObject'

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
