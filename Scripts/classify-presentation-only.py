#!/usr/bin/env python3
"""Fail-closed classifier: are Swift diffs presentation-only (chrome/metrics/copy)?

Prints ``presentation-only`` when every listed tracked path's ``git diff HEAD``
touches only layout metrics, SwiftUI chrome modifiers, SF Symbol / Text copy, or
comments/whitespace. Prints ``behavioral`` otherwise (including untracked files,
empty path lists, and anything uncertain).

Used by Scripts/change-classification.sh to demote local verify package tests /
smoke to compile-only. CI coverage is unchanged.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from classify_diff import changed_lines, git_diff, is_tracked  # noqa: E402

# Lines that are clearly presentation chrome when they are the only edits.
_PRESENTATION_LINE = re.compile(
    r"""^(?:
        \s*|
        //.*|
        /\*.*|
        \*.*|
        \*/.*|
        \#.*|                                  # rare; keep harmless
        (?:public\s+|private\s+|internal\s+|fileprivate\s+)?static\s+let\s+\w+\s*:\s*CGFloat\s*=\s*[\d._]+|
        (?:public\s+|private\s+|internal\s+|fileprivate\s+)?static\s+let\s+\w+\s*:\s*CGFloat\s*=\s*[\d._]+\s*//.*|
        .*TrinketDesign\.Metrics\.\w+.*|
        .*\.(?:
            padding|frame|font|foregroundStyle|background|opacity|shadow|clipShape|
            overlay|lineLimit|minimumScaleFactor|multilineTextAlignment|scaledToFit|
            resizable|contentShape|allowsHitTesting|layoutPriority|zIndex|offset|
            rotationEffect|scaleEffect|blur|mask|border|strokeBorder|fill|
            ignoresSafeArea|safeAreaPadding|containerRelativeFrame|
            trinketTypography|trinketMaterial|trinketCardSurface|trinketSurface|
            monospacedDigit|decorativePreparedArtwork|symbolRenderingMode|
            imageScale|fontWeight|bold|italic|underline|strikethrough|
            kerning|tracking|baselineOffset|textCase|lineSpacing
        )\b.*|
        .*Image\s*\(\s*systemName\s*:\s*"[^"]*"\s*\).*|
        .*systemIcon\s*:\s*"[^"]*".*|
        .*Text\s*\(\s*"[^"]*"\s*\).*|
        .*Text\s*\(\s*"[^"]*"\s*\)\s*$|
        .*"(?:[A-Z][A-Z0-9 .'!?,:;_-]{0,80})"\s*$|  # uppercase UI chrome copy
        .*HomesteadResource\.\w+\.tint.*|
        .*TrinketDesign\.Colors\.\w+.*|
        .*Keyword\.\w+\.visualStyle\.color.*|
        .*spacing\s*:\s*(?:TrinketDesign\.Metrics\.\w+|[\d.]+).*|
        .*width\s*:\s*(?:TrinketDesign\.Metrics\.\w+|[\d.]+).*|
        .*height\s*:\s*(?:TrinketDesign\.Metrics\.\w+|[\d.]+).*|
        .*minHeight\s*:\s*(?:TrinketDesign\.Metrics\.\w+|[\d.]+).*|
        .*maximum\s*:\s*[\d.]+.*|
        .*minimum\s*:\s*(?:TrinketDesign\.Metrics\.\w+\s*\*\s*[\d.]+|[\d.]+).*|
        .*tint\s*:\s*(?:HomesteadResource\.\w+\.tint|TrinketDesign\.Colors\.\w+|\.secondary|\.primary).*|
        .*foregroundStyle\s*\(.*\).*|
        .*font\s*\(\.(?:largeTitle|title|title2|title3|headline|body|callout|subheadline|footnote|caption|caption2).*|
        \)\s*$|
        \]\s*$|
        \}\s*$|
        ,\s*$
    )$""",
    re.VERBOSE,
)

# Any of these in a changed line → behavioral (fail closed).
_BEHAVIORAL_HINT = re.compile(
    r"""(?x)
    AccessibilityID|
    accessibilityIdentifier|
    accessibility[A-Z]\w*|
    @State\b|@Binding\b|@Environment\b|@Bindable\b|@Observable\b|
    \b(?:func|struct|enum|class|actor|protocol|extension|typealias|import)\b|
    \b(?:playerSave|onSelect|onResolve|onFinish|onCorrupt|onCancel|onTapGesture|
       Button\s*\{|Task\s*\{|withAnimation|animation\(|transition\(|
       NavigationStack|sheet\s*\(|fullScreenCover|confirmationDialog|
       guard\s+|switch\s+|for\s+|while\s+|if\s+let|if\s+case)\b|
    \b(?:Session|Store|Applier|Reducer|Handler)\b|
    Image\.preparedAsset|
    preparedAsset\s*\(
    """
)


def _line_is_presentation(line: str) -> bool:
    stripped = line.strip()
    if not stripped:
        return True
    if _BEHAVIORAL_HINT.search(line):
        return False
    return _PRESENTATION_LINE.match(stripped) is not None


def path_is_presentation_only(path: str) -> bool:
    if not path.endswith(".swift"):
        return False
    if not is_tracked(path):
        # New files are fail-closed: too easy to hide logic in an add.
        return False
    diff = git_diff(path)
    if not diff.strip():
        # No diff vs HEAD (e.g. dry-run of an unchanged path) → not a demotion signal.
        return False
    if not changed_lines(diff):
        return False
    return all(_line_is_presentation(line) for line in changed_lines(diff))


def main(argv: list[str]) -> int:
    paths = [p for p in argv[1:] if p]
    if not paths:
        print("behavioral")
        return 0
    if all(path_is_presentation_only(path) for path in paths):
        print("presentation-only")
    else:
        print("behavioral")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
