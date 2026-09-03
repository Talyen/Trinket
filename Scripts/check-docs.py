#!/usr/bin/env python3
"""Check repository documentation for broken local links and known drift."""

from __future__ import annotations

import importlib.util
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def _load_sibling(name: str, filename: str):
    path = Path(__file__).resolve().parent / filename
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {filename}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


_check_links = _load_sibling("check_links", "check-links.py")
_check_testplan_sync = _load_sibling("check_testplan_sync", "check-testplan-sync.py")
_check_plans = _load_sibling("check_plans", "check-plans.py")

SKIP_PARTS = _check_links.SKIP_PARTS
LINK = _check_links.LINK
HEADING = _check_links.HEADING
FENCE = _check_links.FENCE
markdown_files = _check_links.markdown_files
github_slug = _check_links.github_slug
heading_slugs = _check_links.heading_slugs
broken_links = _check_links.broken_links
PLAN_STATUSES = _check_plans.PLAN_STATUSES
ARCHIVED_PLAN_STATUSES = _check_plans.ARCHIVED_PLAN_STATUSES
PLAN_WARNING_DAYS = _check_plans.PLAN_WARNING_DAYS
plan_metadata = _check_plans.plan_metadata
testplan_failures = _check_testplan_sync.testplan_failures
plan_failures = _check_plans.plan_failures
DOC_WARNINGS: list[str] = []
SOURCE_GREP_PATHS = ("Packages", "Trinket", "Scripts", "project.yml")


TEST_SUITE_DECL = re.compile(
    r"\b(?:final\s+)?(?:struct|class|actor|enum)\s+([A-Za-z][A-Za-z0-9_]*Tests)\b"
)


def test_suite_names() -> set[str]:
    """Index existing test suite files and declared *Tests types."""
    names: set[str] = set()
    for swift in (ROOT / "Packages").glob("*/Tests/**/*.swift"):
        text = swift.read_text(encoding="utf-8", errors="replace")
        names.update(TEST_SUITE_DECL.findall(text))
        if swift.stem.endswith("Tests"):
            names.add(swift.stem)
    for tests_dir in (ROOT / "Packages").glob("*/Tests/*"):
        if tests_dir.is_dir():
            names.add(tests_dir.name)
    return names


def source_contains_identifier(identifier: str) -> bool:
    """Return whether an audit evidence identifier still exists in authored source."""
    result = subprocess.run(
        ["git", "-C", str(ROOT), "grep", "-q", "-w", identifier, "--", *SOURCE_GREP_PATHS],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode in {0, 1}:
        return result.returncode == 0
    for root_name in SOURCE_GREP_PATHS:
        root = ROOT / root_name
        paths = [root] if root.is_file() else root.rglob("*") if root.is_dir() else []
        for path in paths:
            if path.is_file() and path.suffix in {".swift", ".py", ".sh", ".mjs", ".yml", ".yaml", ".json"}:
                if re.search(rf"\b{re.escape(identifier)}\b", path.read_text(encoding="utf-8", errors="replace")):
                    return True
    return False


def proposal_evidence_failures() -> list[str]:
    """Require the primary evidence pointer to retain a live source symbol."""
    path = ROOT / "Docs" / "Audits" / "Proposals.md"
    failures: list[str] = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.startswith("|") or "`" not in line:
            continue
        columns = [column.strip() for column in line.strip().strip("|").split("|")]
        if len(columns) < 3 or columns[0] in {"Owning audit", "--------------"}:
            continue
        pointers = re.findall(r"`([^`]+)`", columns[2])
        if not pointers:
            continue
        pointer = pointers[0]
        identifiers = re.findall(r"[A-Za-z_][A-Za-z0-9_]*", pointer)
        if not identifiers:
            continue
        identifier = identifiers[-1]
        if not source_contains_identifier(identifier):
            failures.append(
                f"{path.relative_to(ROOT)}:{line_number}: evidence pointer {pointer!r} "
                f"does not resolve to authored source identifier {identifier!r}"
            )
    return failures


def script_index_failures() -> list[str]:
    """Require every top-level Scripts/*.sh to be indexed in Scripts/README.md.

    Either the Everyday command table or the Advanced/internal table must name
    the script file; otherwise the index drifts and agents miss the owner.
    """
    readme = (ROOT / "Scripts" / "README.md").read_text(encoding="utf-8")
    failures: list[str] = []
    for script in sorted((ROOT / "Scripts").glob("*.sh")):
        if f"Scripts/{script.name}" not in readme:
            failures.append(
                f"Scripts/README.md: command index is missing Scripts/{script.name} "
                "(add it to the Everyday table or the Advanced/internal table)"
            )
    return failures


def structural_checks(files: list[Path], *, final: bool = False, keep_plan: bool = False) -> list[str]:
    failures: list[str] = []
    relative = {path.relative_to(ROOT) for path in files}

    for manifest in sorted((ROOT / "Packages").glob("*/Package.swift")):
        package = manifest.parent.relative_to(ROOT)
        if package / "README.md" not in relative and package / "AGENTS.md" not in relative:
            failures.append(f"{package}: package has neither README.md nor AGENTS.md")

    failures.extend(_check_testplan_sync.testplan_failures())
    failures.extend(script_index_failures())

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
        "follows the proposal bar": "audit right-size policy lives only in Docs/Audits/README.md",
        "A clean pass is valid": "zero-findings-is-success lives only in Docs/Audits/README.md",
        "Swift 6.0": "project.yml sets SWIFT_VERSION to 6.2",
        "accessibility-setting UI test only": "PD-014 forbids accessibility-setting UI tests",
        "do not regenerate on enter": "Labyrinth entry rebuilds unreadable map payloads",
        "TrinketDesign.Metrics": "design tokens are TrinketDesign.Spacing and TrinketDesign.Layout",
        "InelegantSlop": "retired audit name; route to audit 02 or 06",
        "DualPathRetention": "retired audit name; route to audit 06",
        "reduced-transparency handling": "the design system has no reduced-transparency policy",
    }
    for source in files:
        text = source.read_text(encoding="utf-8")
        for phrase, explanation in stale.items():
            if phrase in text:
                failures.append(f"{source.relative_to(ROOT)}: stale phrase {phrase!r} ({explanation})")

    suites = test_suite_names()
    for tests_readme in sorted((ROOT / "Packages").glob("*/Tests/README.md")):
        text = tests_readme.read_text(encoding="utf-8")
        for name in set(re.findall(r"`([A-Za-z][A-Za-z0-9_*]*Tests)`", text)):
            if "*" not in name and name not in suites:
                failures.append(
                    f"{tests_readme.relative_to(ROOT)}: referenced suite {name} does not exist "
                    "under any Packages/*/Tests directory"
                )

    classifier = ROOT / "Scripts" / "change-classification.sh"
    routed_cards = set(re.findall(r"Docs/AgentContext/[A-Za-z0-9_-]+\.md", classifier.read_text(encoding="utf-8")))
    for card in sorted((ROOT / "Docs" / "AgentContext").glob("*.md")):
        if card.name == "README.md":
            continue
        relative_card = f"Docs/AgentContext/{card.name}"
        if relative_card not in routed_cards:
            failures.append(
                f"{relative_card}: context card is not emitted by Scripts/change-classification.sh; "
                "add a route or declare it in a 'lookup-only:' comment there"
            )

    readme_path = ROOT / "Docs" / "AgentContext" / "README.md"
    table_cards: set[str] = set()
    for line in readme_path.read_text(encoding="utf-8").splitlines():
        if not line.lstrip().startswith("|"):
            continue
        for raw in LINK.findall(line):
            target = raw.strip().split(maxsplit=1)[0].strip("<>")
            if re.fullmatch(r"[A-Za-z0-9_-]+\.md", target):
                table_cards.add(f"Docs/AgentContext/{target}")
    unrouted_rows = sorted(table_cards - routed_cards)
    if unrouted_rows:
        failures.append(
            f"{readme_path.relative_to(ROOT)}: trigger-table rows reference cards with no route in "
            f"Scripts/change-classification.sh: {', '.join(unrouted_rows)}"
        )

    failures.extend(_check_plans.plan_failures(files, final=final, keep_plan=keep_plan))
    DOC_WARNINGS.extend(_check_plans.DOC_WARNINGS)
    failures.extend(proposal_evidence_failures())
    return failures


def main() -> int:
    final = False
    keep_plan = False
    for argument in sys.argv[1:]:
        if argument == "--final":
            final = True
        elif argument == "--keep-plan":
            keep_plan = True
        else:
            print(f"Usage: {Path(sys.argv[0]).name} [--final] [--keep-plan]", file=sys.stderr)
            return 2
    files = markdown_files()
    DOC_WARNINGS.clear()
    _check_plans.DOC_WARNINGS.clear()
    failures = broken_links(files) + structural_checks(files, final=final, keep_plan=keep_plan)
    if failures:
        print("Documentation checks failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1
    print(f"Documentation checks passed ({len(files)} Markdown files).")
    for warning in DOC_WARNINGS:
        print(f"Warning: {warning}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
