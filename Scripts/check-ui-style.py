#!/usr/bin/env python3
"""Fast UI style guardrail using ripgrep candidate search + Python allowlists."""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

from internal.cli import ROOT
from internal.policy_scan import candidates, report

SCAN_ROOTS = [
    "Trinket",
    "TrinketUITests",
    "Packages/BattleEngine",
    "Packages/TrinketDesignSystem/Sources",
    "Packages/TrinketFeatureSupport",
    "Packages/TrinketBattleFeature",
    "Packages/TrinketAppState",
    "Packages/TrinketContent",
    "Packages/TrinketCore",
    "Packages/TrinketPersistence",
]

DESIGN_SYSTEM_SOURCES = "Packages/TrinketDesignSystem/Sources/"

DESIGN_HELPERS = {
    "Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/TrinketDesign.swift",
    "Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/CardModifiers.swift",
    "Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/GlassButtons.swift",
    "Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/VisualFoundation.swift",
}

ALLOW_RE = re.compile(r"^\s*//\s*UIStyleCheck:\s*allow\s*-\s*\S", re.MULTILINE)

SYSTEM_COLORS = "|".join(
    line.strip()
    for line in (ROOT / "Scripts/config/system-colors.txt").read_text().splitlines()
    if line.strip() and not line.lstrip().startswith("#")
)
if not SYSTEM_COLORS:
    raise SystemExit("Scripts/config/system-colors.txt must list at least one color")

# Ordered: first matching pattern wins (matches legacy bash case order).
PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    (
        "catalog artwork without explicit display size",
        re.compile(
            r"(?:Image\.preparedAsset\(\s*named:|^\s*named:)\s*"
            r"[A-Za-z_][A-Za-z0-9_]*\.(?:imageName|thumbnailImageName)"
        ),
    ),
    (
        "catalog artwork must use PreparedArtworkImage",
        re.compile(r"Image\.preparedAsset\("),
    ),
    (
        "low quality image interpolation",
        re.compile(r"\.interpolation\(\.low\)"),
    ),
    ("direct accentColor modifier", re.compile(r"\.accentColor\(")),
    ("raw glass button style", re.compile(r"\.buttonStyle\(\.glass(Prominent)?")),
    ("raw glass effect", re.compile(r"\.glassEffect\(")),
    ("raw bordered button style", re.compile(r"\.buttonStyle\(\.bordered(Prominent)?")),
    ("raw button toggle style", re.compile(r"\.toggleStyle\(\.button")),
    (
        "raw material background",
        re.compile(r"\.background\(\.(regular|thin|ultraThin)Material"),
    ),
    (
        "raw material fill",
        re.compile(r"\.fill\(\.(regular|thin|ultraThin)Material"),
    ),
    ("AnyView usage (use @ViewBuilder instead)", re.compile(r"AnyView\(")),
    ("raw RGB color", re.compile(r"Color\s*\(\s*(?:red|white|hue|cgColor|uiColor)\s*:|UIColor\s*\(|#colorLiteral\(")),
    (
        "design asset colors outside the design system",
        re.compile(r"DesignAssetColors\.named"),
    ),
    (
        "system color literal",
        re.compile(
            rf"\.(?:foregroundStyle|foregroundColor|tint|fill|stroke|background|strokeBorder)\(\.(?:{SYSTEM_COLORS})\b"
            rf"|\.shadow\(color:\s*\.(?:{SYSTEM_COLORS})\b"
            rf"|(^|[^A-Za-z0-9_])(?:Color\.(?:{SYSTEM_COLORS})\b|\.(?:{SYSTEM_COLORS})\.opacity\()"
        ),
    ),
    (
        "app-bundle named color",
        re.compile(r'Color\s*\(\s*"[^"]+"\s*,\s*bundle:\s*\.main'),
    ),
    ("app-bundle named color", re.compile(r'Color\s*\(\s*"[^"]+"\s*\)')),
    ("serif typeface (use SF Pro)", re.compile(r"design:\s*\.serif|\.withDesign\(\.serif|withDesign\(\s*\.serif")),
    ("raw SwiftUI font (use trinketTypography)", re.compile(r"\.font\(")),
]

FRAME_RE = re.compile(r"\.frame\((width|height|minWidth|minHeight):")
BUTTON_RE = re.compile(r"Button")

# Advisory only: inline animation constructors in files that never reference
# TrinketMotion. Hints never fail the gate; motion owners with their own tuned
# recipes (battle/Homestead/ceremony motion) may intentionally stay listed.
MOTION_HINT_RE = re.compile(
    r"\.(spring|easeOut|easeInOut|smooth)\(|withAnimation\(|phaseAnimator\(|timingCurve\(|TimelineView\("
)

# Broad ripgrep net — derive it from the same patterns the classifier uses so
# a new guard cannot be added to Python without also being candidate-searchable.
RG_PATTERN = "|".join(
    f"(?:{regex.pattern})" for _, regex in PATTERNS
) + f"|(?:{FRAME_RE.pattern})|(?:{MOTION_HINT_RE.pattern})"


def resolve_scan_paths(explicit: list[str] | None) -> list[str]:
    paths = [str(ROOT / item) for item in (explicit or SCAN_ROOTS)]
    return [path for path in paths if Path(path).exists()]


def candidate_files(scan_paths: list[str]) -> list[Path]:
    """Search with NUL-delimited paths, falling back only when rg is unavailable."""
    try:
        return candidates(RG_PATTERN, scan_paths, ROOT)
    except FileNotFoundError:
        regex = re.compile(RG_PATTERN)
        return [path for path in fallback_list_swift_files(scan_paths)
                if regex.search(path.read_text(encoding="utf-8"))]


def is_allowed(
    file_rel: str,
    line: str,
    previous_line: str,
    previous_context: str,
    pattern: str,
) -> bool:
    if ALLOW_RE.search(line) or ALLOW_RE.search(previous_context):
        return True

    if pattern in {"raw RGB color", "system color literal", "app-bundle named color"}:
        return False

    if pattern == "catalog artwork must use PreparedArtworkImage":
        return "Image.preparedAsset(named:" in line

    if pattern == "design asset colors outside the design system":
        return file_rel.startswith(DESIGN_SYSTEM_SOURCES)

    if pattern == "direct accentColor modifier":
        return False

    if file_rel in DESIGN_HELPERS:
        return True

    if "TrinketDesign.cardShape" in line:
        return True
    if ".fill(" in line and "TrinketDesign.cardShape" in previous_line:
        return True

    if ".buttonStyle(.bordered" in line and (
        "Debug" in previous_context or "Battle Again" in previous_context
    ):
        return True

    if (
        ".buttonStyle(.plain)" in line
        or ".trinketQuietTapButtonStyle()" in line
        or "QuietTapButtonStyle()" in line
    ):
        return True

    return False


def classify_line(
    line: str, in_recent_button: bool, previous_context: str
) -> str | None:
    for name, regex in PATTERNS:
        if regex.search(line):
            return name
    if FRAME_RE.search(line) and in_recent_button and ".font(" in previous_context:
        return "fixed-size interactive control"
    return None


def scan_file(path: Path) -> tuple[list[str], str | None]:
    try:
        rel = path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        rel = path.as_posix()

    text = path.read_text(encoding="utf-8")

    violations: list[str] = []
    lines = text.splitlines()
    for index, line in enumerate(lines):
        line_number = index + 1
        previous_line = lines[index - 1] if index else ""
        previous_context = "\n".join(lines[max(0, index - 5):index])
        in_recent_button = any(BUTTON_RE.search(prior) for prior in lines[max(0, index - 24):index])
        pattern = classify_line(line, in_recent_button, previous_context)
        if pattern and not is_allowed(
            rel, line, previous_line, previous_context, pattern
        ):
            if pattern == "catalog artwork without explicit display size":
                guidance = (
                    "should use PreparedArtworkImage(reference, displaySize: .compact/.full)"
                )
            else:
                guidance = (
                    "should route through TrinketDesign semantic roles or include "
                    "UIStyleCheck: allow"
                )
            violations.append(f"{rel}:{line_number}: {pattern} {guidance}")

    hint = f"{rel}: inline animation without TrinketMotion reference" if (
        "TrinketMotion" not in text and MOTION_HINT_RE.search(text)
    ) else None
    return violations, hint


def fallback_list_swift_files(scan_paths: list[str]) -> list[Path]:
    files = []
    for item in scan_paths:
        path = Path(item)
        if path.is_file() and path.suffix == '.swift':
            files.append(path)
        elif path.is_dir():
            files.extend(sorted(path.rglob('*.swift')))
    return files


def main(argv: list[str]) -> int:
    os.chdir(ROOT)
    scan_paths = resolve_scan_paths(argv[1:] or None)
    violations: list[str] = []
    hints: list[str] = []

    try:
        for path in sorted(set(candidate_files(scan_paths)), key=str):
            findings, hint = scan_file(path)
            violations.extend(findings)
            if hint:
                hints.append(hint)
    except (OSError, UnicodeError, RuntimeError) as exc:
        print(f"error: UI style guardrail scan failed: {exc}", file=sys.stderr)
        return 1

    if violations:
        return report(
            violations, "UI style guardrail found styling or artwork-sizing violations:",
            "UI style guardrail passed.", "UI Style Violation",
            "Use shared TrinketDesign semantic roles for chrome. Reserve UIStyleCheck: allow "
            "for narrowly scoped content/art exceptions and explain the reason nearby.", stream=sys.stdout,
        )

    for hint in hints:
        print(f"motion hint: {hint} (prefer a TrinketMotion recipe when the motion is shared)")
        if os.environ.get("GITHUB_ACTIONS") == "true":
            file, message = hint.split(":", 1)
            print(f"::warning file={file.strip()},title=Motion Hint::{message.strip()}")

    print("UI style guardrail passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
