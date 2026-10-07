#!/usr/bin/env python3
"""Fast UI style guardrail using ripgrep candidate search + Python allowlists."""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

from internal.cli import ROOT

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
    if explicit:
        paths: list[str] = []
        for item in explicit:
            path = Path(item)
            if not path.is_absolute():
                path = ROOT / path
            if path.exists():
                paths.append(str(path))
        return paths
    return [str(ROOT / root) for root in SCAN_ROOTS if (ROOT / root).exists()]


def candidate_files(scan_paths: list[str]) -> list[Path]:
    """Search with NUL-delimited paths, falling back only when rg is unavailable."""
    if not scan_paths:
        return []
    try:
        result = subprocess.run(
            ["rg", "--files-with-matches", "--null", "-g", "*.swift", RG_PATTERN, *scan_paths],
            cwd=ROOT, capture_output=True, text=True, check=False,
        )
    except FileNotFoundError:
        regex = re.compile(RG_PATTERN)
        return [path for path in fallback_list_swift_files(scan_paths)
                if regex.search(path.read_text(encoding="utf-8"))]
    if result.returncode not in (0, 1):
        raise RuntimeError(f"rg failed (exit {result.returncode}): {result.stderr.strip()}")
    return [ROOT / name for name in result.stdout.split("\0") if name]


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
    previous_line = ""
    context_lines: list[str] = []
    recent_button_window = 0

    for line_number, line in enumerate(text.splitlines(), start=1):
        in_recent_button = recent_button_window > 0
        previous_context = "\n".join(context_lines)
        pattern = classify_line(line, in_recent_button, previous_context)
        if pattern and not is_allowed(
            rel, line, previous_line, previous_context, pattern
        ):
            if pattern == "catalog artwork without explicit display size":
                guidance = (
                    "should use Image.preparedAsset(reference, displaySize: .compact/.full)"
                )
            else:
                guidance = (
                    "should route through TrinketDesign semantic roles or include "
                    "UIStyleCheck: allow"
                )
            violations.append(f"{rel}:{line_number}: {pattern} {guidance}")

        if BUTTON_RE.search(line):
            recent_button_window = 24
        elif recent_button_window > 0:
            recent_button_window -= 1

        previous_line = line
        context_lines.append(line)
        if len(context_lines) > 5:
            context_lines = context_lines[1:]

    hint = f"{rel}: inline animation without TrinketMotion reference" if (
        "TrinketMotion" not in text and MOTION_HINT_RE.search(text)
    ) else None
    return violations, hint


def fallback_list_swift_files(scan_paths: list[str]) -> list[Path]:
    files: list[Path] = []
    for root in scan_paths:
        path = Path(root)
        if path.is_file() and path.suffix == ".swift":
            files.append(path)
        elif path.is_dir():
            files.extend(sorted(path.rglob("*.swift")))
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
        print("UI style guardrail found styling or artwork-sizing violations:")
        for violation in violations:
            print(f"  {violation}")
        if os.environ.get("GITHUB_ACTIONS") == "true":
            for violation in violations:
                file, line, message = violation.split(":", 2)
                message = message.strip()
                print(
                    f"::error file={file},line={line},title=UI Style Violation::{message}"
                )
        print()
        print(
            "Use shared TrinketDesign semantic roles for chrome. "
            "Reserve UIStyleCheck: allow for narrowly scoped content/art "
            "exceptions and explain the reason nearby."
        )
        return 1

    for hint in hints:
        print(f"motion hint: {hint} (prefer a TrinketMotion recipe when the motion is shared)")
        if os.environ.get("GITHUB_ACTIONS") == "true":
            file, message = hint.split(":", 1)
            print(f"::warning file={file.strip()},title=Motion Hint::{message.strip()}")

    print("UI style guardrail passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
