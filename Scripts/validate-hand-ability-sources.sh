#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

content_dir="Packages/TrinketContent/Sources/TrinketContent/Content"
inventory="Packages/TrinketContent/Sources/TrinketContent/Generated/AbilityInventory.generated.tsv"

python3 - "$content_dir" "$inventory" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

content_dir = Path(sys.argv[1])
inventory_path = Path(sys.argv[2])
source_re = re.compile(
    r'id:\s*"([^"]+)"\s*,\s*name:\s*"([^"]+)"\s*,\s*tier:\s*\.(\w+)',
    re.DOTALL,
)

source: dict[str, tuple[str, str, Path]] = {}
errors: list[str] = []
for path in sorted(content_dir.glob("AbilityCatalog*.swift")):
    if path.name == "AbilityCatalog.swift":
        continue
    text = path.read_text()
    for match in source_re.finditer(text):
        line_number = text.count("\n", 0, match.start()) + 1
        ability_id, name, tier = match.groups()
        if ability_id in source:
            errors.append(f"{path}:{line_number}: duplicate ability id '{ability_id}'")
        source[ability_id] = (name, tier.lower(), path)

generated: dict[str, tuple[str, str]] = {}
for line_number, line in enumerate(inventory_path.read_text().splitlines(), 1):
    if line_number == 1 or not line.strip() or line.startswith("#"):
        continue
    fields = line.split("\t")
    if len(fields) < 3:
        errors.append(f"{inventory_path}:{line_number}: expected id, name, and tier columns")
        continue
    ability_id, name, tier = fields[:3]
    if ability_id in generated:
        errors.append(f"{inventory_path}:{line_number}: duplicate ability id '{ability_id}'")
    generated[ability_id] = (name, tier.lower())

for ability_id in sorted(set(source) - set(generated)):
    errors.append(f"ability '{ability_id}' is authored but missing from generated inventory")
for ability_id in sorted(set(generated) - set(source)):
    errors.append(f"ability '{ability_id}' is generated but missing from hand-authored catalogs")
for ability_id in sorted(set(source) & set(generated)):
    source_name, source_tier, path = source[ability_id]
    generated_name, generated_tier = generated[ability_id]
    if source_name != generated_name:
        errors.append(
            f"{path}: ability '{ability_id}' name '{source_name}' disagrees with generated '{generated_name}'"
        )
    if source_tier != generated_tier:
        errors.append(
            f"{path}: ability '{ability_id}' tier '{source_tier}' disagrees with generated '{generated_tier}'"
        )

if errors:
    print("Hand ability source validation failed:", file=sys.stderr)
    for error in errors:
        print(f"  - {error}", file=sys.stderr)
    raise SystemExit(1)
print("Hand ability sources OK.")
PY
