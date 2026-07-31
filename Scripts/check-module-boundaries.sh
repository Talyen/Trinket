#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

violations=()

check_no_import() {
  local folder="$1"
  local pattern="$2"
  local reason="$3"

  while IFS= read -r file; do
    [[ -n "$file" ]] && violations+=("$file: $reason")
  done < <(rg -l "$pattern" "$folder" -g '*.swift' 2>/dev/null || true)
}

check_no_package_dependency() {
  local package="$1"
  local dependency="$2"
  local reason="$3"
  local manifest="Packages/$package/Package.swift"

  if rg -q "\"$dependency\"" "$manifest"; then
    violations+=("$manifest: $reason")
  fi
}

# Packages must not import the app module.
while IFS= read -r file; do
  [[ -n "$file" ]] && violations+=("$file: packages must not import Trinket app module")
done < <(rg -l '^import Trinket$' Packages -g '*.swift' 2>/dev/null || true)

# Enforce the package DAG in both source imports and Package.swift declarations.
for forbidden in TrinketContent BattleEngine TrinketPersistence TrinketFeatureSupport TrinketBattleFeature TrinketAppState; do
  check_no_import "Packages/TrinketDesignSystem/Sources" "^import $forbidden$" \
    "TrinketDesignSystem must not import $forbidden"
  check_no_package_dependency TrinketDesignSystem "$forbidden" \
    "TrinketDesignSystem must not depend on $forbidden"
done

# BattleEngine and TrinketPersistence are siblings — no cross-imports.
for pkg in BattleEngine TrinketPersistence; do
  if [[ "$pkg" == "BattleEngine" ]]; then
    forbidden="TrinketPersistence"
  else
    forbidden="BattleEngine"
  fi
  check_no_import "Packages/$pkg/Sources" "^import $forbidden$" \
    "$pkg must not import $forbidden"
  check_no_package_dependency "$pkg" "$forbidden" \
    "$pkg must not depend on $forbidden"
done

for forbidden in TrinketFeatureSupport TrinketBattleFeature TrinketAppState; do
  for package in BattleEngine TrinketPersistence; do
    check_no_import "Packages/$package/Sources" "^import $forbidden$" \
      "$package must not import the higher-level $forbidden module"
    check_no_package_dependency "$package" "$forbidden" \
      "$package must not depend on the higher-level $forbidden package"
  done
done

for forbidden in TrinketBattleFeature TrinketAppState; do
  check_no_import "Packages/TrinketFeatureSupport/Sources" "^import $forbidden$" \
    "TrinketFeatureSupport must not import $forbidden"
  check_no_package_dependency TrinketFeatureSupport "$forbidden" \
    "TrinketFeatureSupport must not depend on $forbidden"
done

# Shared support is presentation-only. Persistence and battle resolution belong
# in the feature adapter target so reusable UI cannot reach stores or rules.
for forbidden in BattleEngine TrinketPersistence; do
  check_no_import "Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport" "^import $forbidden$" \
    "TrinketFeatureSupport must not import $forbidden"
done

check_no_import "Packages/TrinketBattleFeature/Sources" '^import TrinketAppState$' \
  'TrinketBattleFeature must not import TrinketAppState'
check_no_package_dependency TrinketBattleFeature TrinketAppState \
  'TrinketBattleFeature must not depend on TrinketAppState'
check_no_import "Packages/TrinketBattleFeature/Sources" '^import TrinketFeatureAdapters$' \
  'TrinketBattleFeature must depend on pure FeatureSupport, not save-backed adapters'
check_no_package_dependency TrinketBattleFeature TrinketFeatureAdapters \
  'TrinketBattleFeature must not depend on the save-backed FeatureAdapters target'

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
