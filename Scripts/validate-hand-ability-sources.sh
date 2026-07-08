#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

content_dir="Packages/TrinketContent/Sources/TrinketContent/Content"
violations=()

while IFS= read -r file; do
  while IFS= read -r line; do
    if [[ "$line" =~ id:[[:space:]]*\"([^\"]+)\" ]]; then
      ability_id="${BASH_REMATCH[1]}"
      if ! rg -q "id: \"$ability_id\"" "$content_dir"/AbilityCatalog*.swift \
        && ! rg -q "^${ability_id}\t" ContentManifest/abilities.tsv; then
        violations+=("$file: ability id '$ability_id' not found in hand catalogs or abilities.tsv")
      fi
    fi
  done < <(rg 'id: "' "$file" -n || true)
done < <(find "$content_dir" -name 'AbilityCatalog*.swift' ! -name 'AbilityCatalog.swift')

if (( ${#violations[@]} > 0 )); then
  echo "Hand ability source validation failed:" >&2
  for violation in "${violations[@]}"; do
    echo "  - $violation" >&2
  done
  exit 1
fi

echo "Hand ability sources OK."
