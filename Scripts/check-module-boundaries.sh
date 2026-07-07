#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

violations=()

check_no_import() {
  local folder="$1"
  local pattern="$2"
  local reason="$3"

  while IFS= read -r file; do
    if rg -q "$pattern" "$file"; then
      violations+=("$file: $reason")
    fi
  done < <(find "$folder" -name '*.swift' -type f 2>/dev/null)
}

# App layering: BattleShell must not reference Features.
check_no_import "Trinket/BattleShell" 'Features/' 'BattleShell must not reference Features/'

# State must not reference feature views by folder path.
check_no_import "Trinket/State" 'Features/' 'State must not reference Features/'

# Packages must not import the app module.
while IFS= read -r file; do
  if rg -q '^import Trinket$' "$file"; then
    violations+=("$file: packages must not import Trinket app module")
  fi
done < <(find Packages -name '*.swift' -type f 2>/dev/null)

# TrinketDesignSystem must depend on TrinketCore only.
for forbidden in TrinketContent BattleEngine TrinketPersistence; do
  if rg -q "import $forbidden" Packages/TrinketDesignSystem/Sources -g '*.swift'; then
    while IFS= read -r file; do
      violations+=("$file: TrinketDesignSystem must not import $forbidden")
    done < <(rg -l "import $forbidden" Packages/TrinketDesignSystem/Sources -g '*.swift')
  fi
done

# BattleEngine and TrinketPersistence are siblings — no cross-imports.
for pkg in BattleEngine TrinketPersistence; do
  if [[ "$pkg" == "BattleEngine" ]]; then
    forbidden="TrinketPersistence"
  else
    forbidden="BattleEngine"
  fi
  if rg -q "import $forbidden" "Packages/$pkg/Sources" -g '*.swift'; then
    while IFS= read -r file; do
      violations+=("$file: $pkg must not import $forbidden")
    done < <(rg -l "import $forbidden" "Packages/$pkg/Sources" -g '*.swift')
  fi
done

if (( ${#violations[@]} > 0 )); then
  echo "Module boundary violations:" >&2
  for violation in "${violations[@]}"; do
    echo "  - $violation" >&2
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
      file=$(echo "$violation" | cut -d: -f1 | xargs)
      reason=$(echo "$violation" | cut -d: -f2- | xargs)
      echo "::error file=$file,line=1,title=Module Boundary Violation::$reason"
    fi
  done
  exit 1
fi

echo "Module boundaries OK."
