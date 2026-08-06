#!/usr/bin/env python3
"""Fail-closed classifier: is a PlayView.swift diff shell vs subflow wiring?

Prints ``shell`` when any changed line looks like Play mode-card / hub shell.
Prints ``subflow`` when every changed line is only encounter/cover/overlay wiring.
Prints ``uncertain`` otherwise (empty/untracked/mixed/unknown) — keep smoke.

Used by Scripts/change-classification.sh to drop SmokePlayTests when PlayView
edits are subflow-only and no other Play shell path is in the change set.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from classify_diff import changed_lines, git_diff, is_tracked  # noqa: E402

PLAY_VIEW = "Trinket/Features/Play/PlayView.swift"

# Any hit → keep SmokePlayTests (mode-card / hub shell).
_SHELL_HINT = re.compile(
    r"""(?x)
    PlayModeHub|
    PlayBrowsingStack|
    ExploreHub|
    SpiresHub|
    openMode\b|
    navigationPath\b|
    AccessibilityID\.Play\.(?:modesScreen|campaignModeCard|exploreModeCard)|
    campaignModeCard|
    exploreModeCard|
    modesScreen|
    PlayModeHubView|
    PlayModeHubScreen
    """
)

# Lines that are clearly subflow / cover / battle overlay wiring.
_SUBFLOW_HINT = re.compile(
    r"""(?x)
    PlayEncounterCoversModifier|
    MysteryEncounterView|
    ShopEncounterView|
    PlayBattleOverlay|
    activeMysteryEncounter|
    activeShopEncounter|
    onResolveChoice|
    onSelectItem|
    onCorruptItem|
    onCancelCorruptSelection|
    onFinishCorruptionReveal|
    selectActiveMysteryItem|
    resolveActiveMysteryChoice|
    corruptActiveMysteryItem|
    finishActiveMystery|
    dismissActiveMystery|
    beginMysteryEncounter|
    fullScreenCover|
    interactiveDismissDisabled|
    dismissibleSessionBinding|
    restorePlayDestination|
    pendingDestination|
    battle\.|
    encounters\.|
    labyrinth\.|
    journey\.|
    VictoryView|
    DefeatView|
    RetreatConfirm
    """
)

# Structural / import noise that neither proves shell nor blocks subflow.
_NOISE_LINE = re.compile(
    r"""^(?:
        \s*|
        //.*|
        /\*.*|
        \*.*|
        \*/.*|
        import\s+\w+.*|
        \)\s*,?\s*$|
        \]\s*,?\s*$|
        \}\s*,?\s*$|
        \{\s*$|
        ,\s*$
    )$""",
    re.VERBOSE,
)


def classify_changed_lines(changed: list[str]) -> str:
    if not changed:
        return "uncertain"

    substantive = [line for line in changed if not _NOISE_LINE.match(line.strip())]
    if not substantive:
        return "uncertain"

    if any(_SHELL_HINT.search(line) for line in substantive):
        return "shell"

    if all(_SUBFLOW_HINT.search(line) for line in substantive):
        return "subflow"

    return "uncertain"


def classify_play_view_diff(path: str = PLAY_VIEW) -> str:
    if path != PLAY_VIEW and not path.endswith("/PlayView.swift"):
        return "uncertain"
    if not is_tracked(path):
        return "uncertain"
    diff = git_diff(path)
    if not diff.strip():
        return "uncertain"
    return classify_changed_lines(changed_lines(diff))


def main(argv: list[str]) -> int:
    path = argv[1] if len(argv) > 1 else PLAY_VIEW
    print(classify_play_view_diff(path))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
