#!/usr/bin/env bash
# Portable owner for legacy observation/navigation APIs and XCTest migration.
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=lib/rg-check.sh
source Scripts/lib/rg-check.sh

policy_matches="$(python3 Scripts/internal/swift_policy.py api-bans Trinket TrinketUITests Packages)"
while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  trinket_rg_violation "$match"
done <<< "$policy_matches"

trinket_rg_report "API ban violations:" "Platform API bans OK." "API Ban" \
  "Swift Testing migration gate: OK (no XCTest imports in unit targets)"
echo "Swift Testing migration gate: OK (no XCTest imports in unit targets)"
