#!/usr/bin/env python3
"""Fast UI style guardrail using ripgrep candidate search + Python allowlists."""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SCAN_ROOTS = [
    "Trinket",
    "TrinketTests",
    "TrinketUITests",
    "Packages/TrinketDesignSystem/Sources",
    "Packages/TrinketFeatureSupport",
    "Packages/TrinketBattleFeature",
    "Packages/TrinketAppState",
]

DESIGN_HELPERS = {
    "Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/TrinketDesign.swift",
    "Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/Modifiers.swift",
    "Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/VisualFoundation.swift",
}

RGB_ALLOWED = {
    "Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/TrinketDesign.swift",
    "Packages/TrinketDesignSystem/Sources/TrinketDesignSystem/VisualFoundation.swift",
}

ALLOW_RE = re.compile(r"^\s*//\s*UIStyleCheck:\s*allow\s*-\s*\S", re.MULTILINE)

SYSTEM_COLORS = (
    "white|black|red|green|blue|orange|yellow|pink|purple|mint|teal|"
    "indigo|brown|cyan|gray|grey|accentColor"
)

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
    ("raw RGB color", re.compile(r"Color\s*\(\s*red\s*:")),
    ("raw RGB color", re.compile(r"Color\s*\(\s*white\s*:")),
    ("raw RGB color", re.compile(r"UIColor\s*\(")),
    ("raw RGB color", re.compile(r"#colorLiteral\(")),
    (
        "system color literal",
        re.compile(
            rf"\.(foregroundStyle|tint|fill|stroke|background)\(\.({SYSTEM_COLORS})\b"
        ),
    ),
    (
        "system color literal",
        re.compile(rf"(^|[^A-Za-z0-9_])Color\.({SYSTEM_COLORS})\b"),
    ),
    (
        "system color literal",
        re.compile(rf"(^|[^A-Za-z0-9_])\.({SYSTEM_COLORS})\.opacity\("),
    ),
    (
        "app-bundle named color",
        re.compile(r'Color\s*\(\s*"[^"]+"\s*,\s*bundle:\s*\.main'),
    ),
    ("app-bundle named color", re.compile(r'Color\s*\(\s*"[^"]+"\s*\)')),
]

FRAME_RE = re.compile(r"\.frame\((width|height|minWidth|minHeight):")
BUTTON_RE = re.compile(r"Button")

# Broad ripgrep net — Python still classifies and allowlists precisely.
RG_PATTERN = (
    r"\.accentColor\(|\.buttonStyle\(\.glass|\.glassEffect\(|\.buttonStyle\(\.bordered|"
    r"\.toggleStyle\(\.button|\.background\(\.(regular|thin|ultraThin)Material|"
    r"\.fill\(\.(regular|thin|ultraThin)Material|AnyView\(|Color\s*\(\s*red\s*:|"
    r"Color\s*\(\s*white\s*:|UIColor\s*\(|#colorLiteral\(|"
    r"\.(foregroundStyle|tint|fill|stroke|background)\(\.(white|black|red|green|blue|"
    r"orange|yellow|pink|purple|mint|teal|indigo|brown|cyan|gray|grey|accentColor)|"
    r"Color\.(white|black|red|green|blue|orange|yellow|pink|purple|mint|teal|indigo|"
    r"brown|cyan|gray|grey|accentColor)|"
    r"\.(white|black|red|green|blue|orange|yellow|pink|purple|mint|teal|indigo|brown|"
    r"cyan|gray|grey|accentColor)\.opacity\(|"
    r'Color\s*\(\s*"[^"]+"|'
    r"Image\.preparedAsset\(\s*named:|^\s*named:\s*[A-Za-z_][A-Za-z0-9_]*\.|"
    r"\.frame\((width|height|minWidth|minHeight):"
)


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


def candidate_hits(scan_paths: list[str]) -> dict[Path, set[int]] | None:
    """Map file -> line numbers that look like potential violations.

    Returns an empty dict when rg finds no candidates, or None when rg is
    unavailable (caller should fall back to a full Swift scan). Raises
    RuntimeError when rg is present but the search fails — fail closed.
    """
    if not scan_paths:
        return {}
    cmd = [
        "rg",
        "-n",
        "--no-heading",
        "--with-filename",
        "-g",
        "*.swift",
        RG_PATTERN,
        *scan_paths,
    ]
    try:
        result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, check=False)
    except FileNotFoundError:
        return None
    if result.returncode not in (0, 1):
        stderr = (result.stderr or "").strip()
        detail = f": {stderr}" if stderr else ""
        raise RuntimeError(f"rg failed (exit {result.returncode}){detail}")
    hits: dict[Path, set[int]] = {}
    for line in result.stdout.splitlines():
        # path:line:content — path may contain colons on exotic FS; split from left twice.
        parts = line.split(":", 2)
        if len(parts) < 2:
            continue
        path = Path(parts[0])
        if not path.is_absolute():
            path = ROOT / path
        try:
            line_no = int(parts[1])
        except ValueError:
            continue
        hits.setdefault(path, set()).add(line_no)
    return hits


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
        if pattern == "raw RGB color" and file_rel in RGB_ALLOWED:
            return True
        return False

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


def scan_file(path: Path) -> list[str]:
    try:
        rel = path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        rel = path.as_posix()

    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"warning: unable to read {rel}: {exc}", file=sys.stderr)
        return []

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

    return violations


def fallback_list_swift_files(scan_paths: list[str]) -> list[Path]:
    files: list[Path] = []
    for root in scan_paths:
        path = Path(root)
        if path.is_file() and path.suffix == ".swift":
            files.append(path)
        elif path.is_dir():
            # Prefer git-aware listing when possible.
            result = subprocess.run(
                ["rg", "--files", "-g", "*.swift", str(path)],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )
            if result.returncode in (0, 1) and result.stdout.strip():
                for line in result.stdout.splitlines():
                    p = Path(line)
                    files.append(p if p.is_absolute() else ROOT / p)
            else:
                files.extend(sorted(path.rglob("*.swift")))
    return files


def main(argv: list[str]) -> int:
    os.chdir(ROOT)
    scan_paths = resolve_scan_paths(argv[1:] or None)
    violations: list[str] = []

    try:
        hits = candidate_hits(scan_paths)
    except RuntimeError as exc:
        print(f"error: UI style guardrail search failed: {exc}", file=sys.stderr)
        return 1

    if hits is None:
        # rg unavailable — fall back to listed Swift files.
        for path in fallback_list_swift_files(scan_paths):
            violations.extend(scan_file(path))
    elif hits:
        # Only open files ripgrep flagged — avoids full-tree iCloud/Documents I/O.
        for path in sorted(hits, key=str):
            violations.extend(scan_file(path))
    # else: rg ran cleanly with zero candidates — pass without a full read.

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

    print("UI style guardrail passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
