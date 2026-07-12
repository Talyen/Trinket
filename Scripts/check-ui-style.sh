#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

violations=()

is_allowed_line() {
  local file="$1"
  local line_number="$2"
  local line="$3"
  local previous_line="${4:-}"
  local previous_context="${5:-}"
  local pattern="${6:-}"

  if [[ "$line" == *"UIStyleCheck: allow"* || "$previous_context" == *"UIStyleCheck: allow"* ]]; then
    return 0
  fi

  # Raw RGB / system color literals / app-bundle Color("…") belong in DesignColors via DesignAssetColors.
  if [[ "$pattern" == "raw RGB color" || "$pattern" == "system color literal" || "$pattern" == "app-bundle named color" ]]; then
    if [[ "$pattern" == "raw RGB color" ]]; then
      if [[ "$file" == "Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/TrinketDesign.swift" || "$file" == "Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/VisualFoundation.swift" ]]; then
        return 0
      fi
    fi
    # System / app-bundle named colors must not appear in product or design-system sources — use assets.
    return 1
  fi

  # accentColor bypasses the app-wide semantic tint, including inside shared helpers.
  if [[ "$pattern" == "direct accentColor modifier" ]]; then
    return 1
  fi

  # Central styling helpers are the approved place for raw glass/material details.
  if [[ "$file" == "Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/TrinketDesign.swift" || "$file" == "Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/Modifiers.swift" || "$file" == "Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/VisualFoundation.swift" ]]; then
    return 0
  fi

  # Existing inspectable card surfaces can keep their current material until they are migrated.
  if [[ "$line" == *"TrinketDesign.cardShape"* ]]; then
    return 0
  fi

  if [[ "$line" == *".fill("* && "$previous_line" == *"TrinketDesign.cardShape"* ]]; then
    return 0
  fi

  # Debug harness controls and the current primary CTA intentionally use standard bordered styles.
  if [[ "$line" == *".buttonStyle(.bordered"* && ( "$previous_context" == *"Debug"* || "$previous_context" == *"Battle Again"* ) ]]; then
    return 0
  fi

  # Plain buttons are commonly used to make tappable cards keep their custom card artwork.
  if [[ "$line" == *".buttonStyle(.plain)"* ]]; then
    return 0
  fi

  return 1
}

check_line() {
  local file="$1"
  local line_number="$2"
  local line="$3"
  local previous_line="${4:-}"
  local previous_context="${5:-}"
  local in_recent_button="${6:-0}"

  local pattern=""

  case "$line" in
    *".accentColor("*)
      pattern="direct accentColor modifier"
      ;;
    *".buttonStyle(.glass"*|*".buttonStyle(.glassProminent"*)
      pattern="raw glass button style"
      ;;
    *".glassEffect("*)
      pattern="raw glass effect"
      ;;
    *".buttonStyle(.bordered"*|*".buttonStyle(.borderedProminent"*)
      pattern="raw bordered button style"
      ;;
    *".toggleStyle(.button"*)
      pattern="raw button toggle style"
      ;;
    *".background(.regularMaterial"*|*".background(.thinMaterial"*|*".background(.ultraThinMaterial"*)
      pattern="raw material background"
      ;;
    *".fill(.regularMaterial"*|*".fill(.thinMaterial"*|*".fill(.ultraThinMaterial"*)
      pattern="raw material fill"
      ;;
    *"AnyView("*)
      pattern="AnyView usage (use @ViewBuilder instead)"
      ;;
    *".frame(width:"*|*".frame(height:"*|*".frame(minWidth:"*|*".frame(minHeight:"*)
      if [[ "$in_recent_button" == "1" && "$previous_context" == *".font("* ]]; then
        pattern="fixed-size interactive control"
      fi
      ;;
  esac

  if [[ -z "$pattern" && "$line" =~ Color[[:space:]]*\([[:space:]]*red[[:space:]]*: ]]; then
    pattern="raw RGB color"
  fi

  if [[ -z "$pattern" && "$line" =~ Color[[:space:]]*\([[:space:]]*white[[:space:]]*: ]]; then
    pattern="raw RGB color"
  fi

  if [[ -z "$pattern" && "$line" =~ UIColor[[:space:]]*\( ]]; then
    pattern="raw RGB color"
  fi

  if [[ -z "$pattern" && "$line" == *"#colorLiteral("* ]]; then
    pattern="raw RGB color"
  fi

  # SwiftUI system palette used as chrome (adaptive .primary/.secondary/.clear are fine).
  if [[ -z "$pattern" ]]; then
    if [[ "$line" =~ \.(foregroundStyle|tint|fill|stroke|background)\(\.(white|black|red|green|blue|orange|yellow|pink|purple|mint|teal|indigo|brown|cyan|gray|grey) ]]; then
      pattern="system color literal"
    elif [[ "$line" =~ (^|[^A-Za-z0-9_])Color\.(white|black|red|green|blue|orange|yellow|pink|purple|mint|teal|indigo|brown|cyan|gray|grey)\b ]]; then
      pattern="system color literal"
    elif [[ "$line" =~ (^|[^A-Za-z0-9_])\.(white|black|red|green|blue|orange|yellow|pink|purple|mint|teal|indigo|brown|cyan|gray|grey)\.opacity\( ]]; then
      pattern="system color literal"
    fi
  fi

  if [[ -z "$pattern" && "$line" =~ Color[[:space:]]*\([[:space:]]*\"[^\"]+\"[[:space:]]*,[[:space:]]*bundle:[[:space:]]*\.main ]]; then
    pattern="app-bundle named color"
  fi

  # Bare Color("AssetName") bypasses DesignAssetColors / TrinketDesign.Colors.
  if [[ -z "$pattern" && "$line" =~ Color[[:space:]]*\([[:space:]]*\"[^\"]+\"[[:space:]]*\) ]]; then
    pattern="app-bundle named color"
  fi

  if [[ -z "$pattern" ]]; then
    return
  fi

  if is_allowed_line "$file" "$line_number" "$line" "$previous_line" "$previous_context" "$pattern"; then
    return
  fi

  violations+=("$file:$line_number: $pattern should route through TrinketDesign semantic roles or include UIStyleCheck: allow")
}

while IFS= read -r file; do
  previous_line=""
  previous_context=""
  line_number=0
  recent_button_window=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))

    button_context=0
    if [[ "$recent_button_window" -gt 0 ]]; then
      button_context=1
    fi

    check_line "$file" "$line_number" "$line" "$previous_line" "$previous_context" "$button_context"

    if [[ "$line" == *"Button"* ]]; then
      recent_button_window=24
    elif [[ "$recent_button_window" -gt 0 ]]; then
      recent_button_window=$((recent_button_window - 1))
    fi

    previous_line="$line"
    previous_context="${previous_context}
${line}"
    previous_context="$(printf '%s\n' "$previous_context" | tail -n 5)"
  done < "$file"
done < <(rg --files -g '*.swift' Trinket TrinketTests TrinketUITests Packages/TrinketDesignSystem/Sources)

if [[ ${#violations[@]} -gt 0 ]]; then
  echo "UI style guardrail found ad hoc native styling:"
  printf '  %s\n' "${violations[@]}"

  if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    for violation in "${violations[@]}"; do
      file=$(echo "$violation" | cut -d: -f1)
      line=$(echo "$violation" | cut -d: -f2)
      message=$(echo "$violation" | cut -d: -f3- | xargs)
      echo "::error file=$file,line=$line,title=UI Style Violation::$message"
    done
  fi

  echo
  echo "Use shared TrinketDesign semantic roles for chrome. Reserve UIStyleCheck: allow for narrowly scoped content/art exceptions and explain the reason nearby."
  exit 1
fi

echo "UI style guardrail passed."
