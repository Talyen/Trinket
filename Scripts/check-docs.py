#!/usr/bin/env python3
"""Check repository documentation for broken local links and known drift."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

from internal.cli import ROOT, load_sibling
from internal.doc_diagnostics import report_failures
from internal.change_routing import guidance_references
from internal.agent_tasks import load_tasks, validate_reference


_check_links = load_sibling("check_links", "check-links.py")
_check_testplan_sync = load_sibling("check_testplan_sync", "check-testplan-sync.py")
_check_plans = load_sibling("check_plans", "check-plans.py")

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
        ["git", "-C", str(ROOT), "grep", "--untracked", "-q", "-w", identifier, "--", *SOURCE_GREP_PATHS,
         ":(exclude)*.md", ":(exclude)*.mdc"],
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
            for raw in _check_links.LINK.findall(line):
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

    suites = test_suite_names()
    for tests_readme in sorted((ROOT / "Packages").glob("*/Tests/README.md")):
        text = tests_readme.read_text(encoding="utf-8")
        for name in set(re.findall(r"`([A-Za-z][A-Za-z0-9_*]*Tests)`", text)):
            if "*" not in name and name not in suites:
                failures.append(
                    f"{tests_readme.relative_to(ROOT)}: referenced suite {name} does not exist "
                    "under any Packages/*/Tests directory"
                )

    references = guidance_references()
    try:
        references.update(reference for task in load_tasks(ROOT) for reference in task['contracts'])
        for reference in sorted(references):
            validate_reference(ROOT, reference)
    except (OSError, ValueError) as error:
        failures.append(f'Guidance routing: {error}')

    failures.extend(_check_plans.plan_failures(files, final=final, keep_plan=keep_plan, paths=paths))
    failures.extend(proposal_evidence_failures())
    failures.extend(audit_inventory_failures())
    return failures


def main() -> int:
    args = _check_plans.parse_arguments(__doc__)
    files = _check_links.markdown_files()
    _check_plans.DOC_WARNINGS.clear()
    failures = _check_links.broken_links(files) + structural_checks(
        files, final=args.final, keep_plan=args.keep_plan, paths=args.paths,
    )
    if failures:
        report_failures("Documentation checks failed:", failures, root=ROOT)
        return 1
    print(f"Documentation checks passed ({len(files)} Markdown files).")
    for warning in _check_plans.DOC_WARNINGS:
        print(f"Warning: {warning}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
