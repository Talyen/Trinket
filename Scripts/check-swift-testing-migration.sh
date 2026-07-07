#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

violations=()
while IFS= read -r -d '' file; do
  if [[ "$file" == *TrinketUITests/* ]]; then
    continue
  fi
  violations+=("$file")
done < <(rg -l 'import XCTest' TrinketTests Packages --glob '*Tests/**/*.swift' --glob '!**/TrinketUITests/**' -0 2>/dev/null || true)

if ((${#violations[@]} > 0)); then
  echo "error: XCTest imports remain outside TrinketUITests:" >&2
  printf '  %s\n' "${violations[@]}" >&2
  exit 1
fi

echo "Swift Testing migration gate: OK (no XCTest imports in unit targets)"
