#!/usr/bin/env python3
"""Check repository documentation for broken local links and known drift."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

from internal.cli import ROOT, load_sibling


_check_links = load_sibling("check_links", "check-links.py")
_check_testplan_sync = load_sibling("check_testplan_sync", "check-testplan-sync.py")
_check_plans = load_sibling("check_plans", "check-plans.py")

SKIP_PARTS = _check_links.SKIP_PARTS
LINK = _check_links.LINK
markdown_files = _check_links.markdown_files
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


AUDIT_GUIDE_PATTERN = re.compile(r"^(\d{2})_[A-Za-z0-9]+\.md$")
AUDIT_RETIRED_NUMBERS = {"05", "08", "11"}


def audit_inventory_failures() -> list[str]:
    """Keep the audit ownership table, guide files, and retired numbers consistent."""
    audits_dir = ROOT / "Docs" / "Audits"
    failures: list[str] = []
    guides: dict[str, str] = {}
    if audits_dir.is_dir():
        for path in sorted(audits_dir.glob("[0-9][0-9]_*.md")):
            match = AUDIT_GUIDE_PATTERN.match(path.name)
            if match:
                guides[path.name] = match.group(1)
    linked: set[str] = set()
    readme = audits_dir / "README.md"
    if readme.is_file():
        in_ownership = False
        for line in readme.read_text(encoding="utf-8").splitlines():
            stripped = line.strip()
            if stripped.startswith("#"):
                if stripped == "## Ownership":
                    in_ownership = True
                elif in_ownership:
                    break
                continue
            if not in_ownership:
                continue
            for raw in LINK.findall(line):
                target = raw.strip().split(maxsplit=1)[0].strip("<>")
                if "/" not in target and AUDIT_GUIDE_PATTERN.match(Path(target).name):
                    linked.add(Path(target).name)
    for name in sorted(set(guides) - linked):
        failures.append(
            f"Docs/Audits/{name}: guide is not listed in the Docs/Audits/README.md ownership table"
        )
    for name in sorted(linked - set(guides)):
        failures.append(
            f"Docs/Audits/README.md: ownership table links {name}, which does not exist"
        )
    for name, number in sorted(guides.items()):
        if number in AUDIT_RETIRED_NUMBERS:
            failures.append(f"Docs/Audits/{name}: reuses retired audit number {number}")
        lines = (audits_dir / name).read_text(encoding="utf-8").splitlines()
        heading = next((line for line in lines if line.startswith("# ")), "")
        if not heading.startswith(f"# {number}."):
            failures.append(
                f"Docs/Audits/{name}: top heading does not start with '# {number}.'"
            )
    return failures


def script_index_failures() -> list[str]:
    """Keep the exhaustive command inventory out of the everyday entry page."""
    reference = ROOT / "Scripts" / "Reference.md"
    if not reference.is_file():
        return ["Scripts/Reference.md: command reference is missing"]
    text = reference.read_text(encoding="utf-8")
    failures: list[str] = []
    for script in sorted((ROOT / "Scripts").glob("*.sh")):
        if f"Scripts/{script.name}" not in text:
            failures.append(
                f"Scripts/Reference.md: command index is missing Scripts/{script.name} "
                "(add it to the owning section)"
            )
    # Stale rows point at scripts that no longer exist; the missing-script
    # loop above cannot catch them.
    for mentioned in sorted(set(re.findall(r"Scripts/([A-Za-z0-9_.-]+\.sh)", text))):
        if not (ROOT / "Scripts" / mentioned).is_file():
            failures.append(
                f"Scripts/Reference.md: command index references Scripts/{mentioned}, "
                "which does not exist (remove the row)"
            )
    return failures


def structural_checks(
    files: list[Path], *, final: bool = False, keep_plan: bool = False,
    paths: set[Path] | None = None,
) -> list[str]:
    failures: list[str] = []
    relative = {path.relative_to(ROOT) for path in files}

    for manifest in sorted((ROOT / "Packages").glob("*/Package.swift")):
        package = manifest.parent.relative_to(ROOT)
        if package / "README.md" not in relative and package / "AGENTS.md" not in relative:
            failures.append(f"{package}: package has neither README.md nor AGENTS.md")

    failures.extend(_check_testplan_sync.testplan_failures())
    failures.extend(script_index_failures())

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

    failures.extend(_check_plans.plan_failures(files, final=final, keep_plan=keep_plan, paths=paths))
    DOC_WARNINGS.extend(_check_plans.DOC_WARNINGS)
    failures.extend(proposal_evidence_failures())
    failures.extend(audit_inventory_failures())
    return failures


def main() -> int:
    args = _check_plans.parse_arguments(__doc__)
    files = markdown_files()
    DOC_WARNINGS.clear()
    _check_plans.DOC_WARNINGS.clear()
    failures = broken_links(files) + structural_checks(
        files, final=args.final, keep_plan=args.keep_plan, paths=args.paths,
    )
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
