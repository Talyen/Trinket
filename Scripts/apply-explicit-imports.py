#!/usr/bin/env python3
"""Add explicit package imports to Trinket app Swift sources."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRINKET = ROOT / "Trinket"

IMPORT_RULES: list[tuple[str, list[str]]] = [
    (
        "TrinketCore",
        [
            r"\bKeyword\b",
            r"\bPrimaryStats\b",
            r"\bItemSlot\b",
            r"\bEffectKind\b",
            r"\bEffectSummary\b",
            r"\bHomesteadTint\b",
            r"\bHomesteadResource\b",
            r"\bHomesteadNodeID\b",
            r"\bHomesteadNodeCategory\b",
            r"\bResourceAmount\b",
            r"\bAbilityTier\b",
            r"\bCombatantProgression\b",
            r"\bGrowthArchetype\b",
            r"\bItemAffixDefinition\b",
            r"\bChapterTheme\b",
        ],
    ),
    (
        "TrinketContent",
        [
            r"\bGameContent\b",
            r"\bCombatant\b",
            r"\bAbility\b",
            r"\bStage\b",
            r"\bChapter\b",
            r"\bEnemy\b",
            r"\bInventoryItem\b",
            r"\bItemBaseType\b",
            r"\bItemAffixCatalog\b",
            r"\bAbilityCatalog\b",
            r"\bArtCatalog\b",
            r"\bMusicCatalog\b",
            r"\bEncounterArtReference\b",
            r"\bCombatantArtReference\b",
            r"\bAbilityArtReference\b",
            r"\bItemArtReference\b",
            r"\bHomesteadNodeDefinition\b",
            r"\bStageEncounter\b",
            r"\bStageReward\b",
            r"\bMusicTrack\b",
            r"\bMusicTrackKind\b",
        ],
    ),
    (
        "BattleEngine",
        [
            r"\bBattleState\b",
            r"\bBattleActionEvent\b",
            r"\bBattleLoopEngine\b",
            r"\bBattleSimulator\b",
            r"\bBattleOutcome\b",
            r"\bCombatOutcome\b",
            r"\bActionEvent\b",
            r"\bActionEventDisplay\b",
            r"\bActionEventFormatter\b",
            r"\bCombatBuild\b",
        ],
    ),
    (
        "TrinketPersistence",
        [
            r"\bPlayerSaveStore\b",
            r"\bPlayerRosterStore\b",
            r"\bPlayerInventoryStore\b",
            r"\bPlayerInventoryState\b",
            r"\bPlayerRosterState\b",
            r"\bPlayerHomesteadStore\b",
            r"\bPlayerJourneyStore\b",
            r"\bPlayerSaveSyncCoordinator\b",
            r"\bPlayerSaveSyncing\b",
            r"\bSavedRosterState\b",
            r"\bSavedInventoryState\b",
            r"\bSavedHomesteadState\b",
            r"\bPlayerSaveFileStore\b",
            r"\bPlayerSave\b",
            r"\bPlayerHomesteadState\b",
            r"\bJourneyProgressState\b",
            r"\bStageCompletion\b",
            r"\bStageCompletionContext\b",
        ],
    ),
    (
        "TrinketDesignSystem",
        [
            r"\bTrinketDesign\b",
            r"\bExperienceBar\b",
        ],
    ),
]

IMPORT_LINE = re.compile(r"^import\s+(\S+)")
IMPORT_SORT_ORDER = [
    "BattleEngine",
    "Foundation",
    "Observation",
    "SwiftUI",
    "UIKit",
    "TrinketContent",
    "TrinketCore",
    "TrinketDesignSystem",
    "TrinketPersistence",
]
SKIP_FILES = {
    TRINKET / "App" / "ExportedDependencies.swift",
}


def needed_imports(text: str) -> list[str]:
    imports: list[str] = []
    for module, patterns in IMPORT_RULES:
        if any(re.search(pattern, text) for pattern in patterns):
            imports.append(module)
    return imports


def import_sort_key(module: str) -> tuple[int, str]:
    try:
        return (IMPORT_SORT_ORDER.index(module), module)
    except ValueError:
        return (len(IMPORT_SORT_ORDER), module)


def normalize_imports(lines: list[str]) -> list[str]:
    prefix: list[str] = []
    imports: list[str] = []
    suffix: list[str] = []
    section = "prefix"

    for line in lines:
        if line.startswith("import "):
            module = IMPORT_LINE.match(line).group(1)  # type: ignore[union-attr]
            if module not in imports:
                imports.append(module)
            section = "imports"
            continue

        if section == "imports" and line.strip() == "":
            section = "suffix"
            suffix.append(line)
            continue

        if section == "prefix":
            prefix.append(line)
        else:
            suffix.append(line)

    imports.sort(key=import_sort_key)

    if not imports:
        return lines

    body: list[str] = []
    if prefix:
        body.extend(prefix)
    body.extend(f"import {module}" for module in imports)
    if suffix:
        while suffix and suffix[0].strip() == "":
            suffix.pop(0)
        body.append("")
        body.extend(suffix)

    return body


def apply_imports(path: Path) -> bool:
    text = path.read_text()
    original_lines = text.splitlines()
    existing = {match.group(1) for match in IMPORT_LINE.finditer(text)}
    required = [module for module in needed_imports(text) if module not in existing]

    lines = list(original_lines)
    if required:
        insert_at = 0
        for index, line in enumerate(lines):
            if line.startswith("import "):
                insert_at = index + 1
            elif line.strip() and not line.startswith("//") and insert_at == 0:
                break

        for module in required:
            lines.insert(insert_at, f"import {module}")
            insert_at += 1

    normalized = normalize_imports(lines)
    changed = normalized != original_lines
    if changed:
        path.write_text("\n".join(normalized) + "\n")
    return changed


def main() -> int:
    changed = 0
    for path in sorted(TRINKET.rglob("*.swift")):
        if path in SKIP_FILES:
            continue
        if apply_imports(path):
            print(f"updated {path.relative_to(ROOT)}")
            changed += 1
    print(f"Updated {changed} file(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
