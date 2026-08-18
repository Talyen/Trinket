#!/usr/bin/env python3
"""Check repository documentation for broken local links and known drift."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
SKIP_PARTS = {".git", ".DerivedData", ".tools", ".build", "Generated"}
LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
HEADING = re.compile(r"^(#{1,6})\s+(.+?)(?:\s+#*)?\s*$")
FENCE = re.compile(r"^(`{3,}|~{3,})")


def markdown_files() -> list[Path]:
    return sorted(
        path
        for path in ROOT.rglob("*.md")
        if not SKIP_PARTS.intersection(path.relative_to(ROOT).parts)
    )


def github_slug(heading: str) -> str:
    text = heading.strip().lower()
    text = re.sub(r"[^\w\s-]", "", text, flags=re.UNICODE)
    return re.sub(r"[-\s]+", "-", text).strip("-")


def heading_slugs(path: Path) -> set[str]:
    slugs: set[str] = set()
    counts: dict[str, int] = {}
    in_fence = False
    for line in path.read_text(encoding="utf-8").splitlines():
        if FENCE.match(line):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        match = HEADING.match(line)
        if match is None:
            continue
        base = github_slug(match.group(2))
        if not base:
            continue
        seen = counts.get(base, 0)
        counts[base] = seen + 1
        slugs.add(base if seen == 0 else f"{base}-{seen}")
    return slugs


def broken_links(files: list[Path]) -> list[str]:
    failures: list[str] = []
    slug_cache: dict[Path, set[str]] = {}
    for source in files:
        in_fence = False
        for line_number, line in enumerate(source.read_text(encoding="utf-8").splitlines(), 1):
            if FENCE.match(line):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            for raw in LINK.findall(line):
                target = raw.strip().split(maxsplit=1)[0].strip("<>")
                if not target or target.startswith(("http://", "https://", "mailto:")):
                    continue
                path_text, _, fragment = unquote(target).partition("#")
                if path_text:
                    resolved = (source.parent / path_text).resolve()
                    if not resolved.exists():
                        failures.append(
                            f"{source.relative_to(ROOT)}:{line_number}: missing link target {path_text}"
                        )
                        continue
                else:
                    resolved = source
                if not fragment:
                    continue
                if resolved.is_dir():
                    resolved = resolved / "README.md"
                if resolved.suffix != ".md" or not resolved.is_file():
                    continue
                slugs = slug_cache.setdefault(resolved, heading_slugs(resolved))
                if fragment not in slugs:
                    failures.append(
                        f"{source.relative_to(ROOT)}:{line_number}: missing heading #{fragment}"
                    )
    return failures


def structural_checks(files: list[Path]) -> list[str]:
    failures: list[str] = []
    relative = {path.relative_to(ROOT) for path in files}

    for manifest in sorted((ROOT / "Packages").glob("*/Package.swift")):
        package = manifest.parent.relative_to(ROOT)
        if package / "README.md" not in relative and package / "AGENTS.md" not in relative:
            failures.append(f"{package}: package has neither README.md nor AGENTS.md")

    plan = json.loads((ROOT / "Smoke.xctestplan").read_text(encoding="utf-8"))
    selected = {
        test
        for target in plan["testTargets"]
        for test in target.get("selectedTests", [])
    }
    registry = {
        line.strip()
        for line in (ROOT / "Scripts" / "config" / "smoke-classes.txt").read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.strip().startswith("#")
    }
    if selected != registry:
        failures.append(
            "Smoke.xctestplan selectedTests must match Scripts/config/smoke-classes.txt "
            f"(plan={sorted(selected)}, registry={sorted(registry)})"
        )
    ui_source = "\n".join(
        path.read_text(encoding="utf-8")
        for path in sorted((ROOT / "TrinketUITests").rglob("*.swift"))
    )
    for test_class in sorted(selected):
        if not re.search(rf"\b(?:final\s+)?class\s+{re.escape(test_class)}\b", ui_source):
            failures.append(f"Smoke.xctestplan: selected class {test_class} is not declared")

    stale = {
        "five-surface selector matrix": "smoke plan is SmokeShellTests, SmokeBattleTests, SmokeShopTests",
        "six-surface selector matrix": "smoke plan is SmokeShellTests, SmokeBattleTests, SmokeShopTests",
        "QuickSmoke": "local and CI smoke share Smoke.xctestplan",
        "Homestead canary": "bare test.sh smoke runs the three-class smoke plan",
        "seven-resource": "Homestead wallet has eight HomesteadResource cases",
        "BattleRuntimeSession": "runtime owner is BattleRuntime/BattleSession",
        "art.json": "art manifest is ArtManifest/curated-assets.tsv",
        "TrinketBattleEngine": "package scheme is BattleEngine",
        "Task→Command Router": "command routing lives in Docs/Platform/Verification.md",
    }
    for source in files:
        text = source.read_text(encoding="utf-8")
        for phrase, explanation in stale.items():
            if phrase in text:
                failures.append(f"{source.relative_to(ROOT)}: stale phrase {phrase!r} ({explanation})")

    plans_dir = ROOT / "Docs" / "Plans"
    extra_plans = sorted(
        path.name
        for path in plans_dir.glob("*.md")
        if path.name != "README.md"
    )
    if extra_plans:
        failures.append(
            "Docs/Plans/: extra markdown besides README.md "
            f"({', '.join(extra_plans)}); finished plans must be deleted"
        )
    return failures


def main() -> int:
    files = markdown_files()
    failures = broken_links(files) + structural_checks(files)
    if failures:
        print("Documentation checks failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1
    print(f"Documentation checks passed ({len(files)} Markdown files).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
