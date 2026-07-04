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
            r"\bHomesteadTint\b",
            r"\bHomesteadResource\b",
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
            r"\bJourneyProgressState\b",
            r"\bStageCompletion\b",
            r"\bStageCompletionContext\b",
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
        ],
    ),
    (
        "TrinketPersistence",
        [
            r"\bPlayerSaveStore\b",
            r"\bPlayerRosterStore\b",
            r"\bPlayerInventoryStore\b",
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
SKIP_FILES = {
    TRINKET / "App" / "ExportedDependencies.swift",
}


def needed_imports(text: str) -> list[str]:
    imports: list[str] = []
    for module, patterns in IMPORT_RULES:
        if any(re.search(pattern, text) for pattern in patterns):
            imports.append(module)
    return imports


def apply_imports(path: Path) -> bool:
    text = path.read_text()
    existing = {match.group(1) for match in IMPORT_LINE.finditer(text)}
    required = [module for module in needed_imports(text) if module not in existing]
    if not required:
        return False

    lines = text.splitlines()
    insert_at = 0
    for index, line in enumerate(lines):
        if line.startswith("import "):
            insert_at = index + 1
        elif line.strip() and not line.startswith("//") and insert_at == 0:
            break

    for module in reversed(required):
        lines.insert(insert_at, f"import {module}")

    path.write_text("\n".join(lines) + "\n")
    return True


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
