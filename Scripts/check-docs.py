#!/usr/bin/env python3
"""Check repository documentation for broken local links and known drift."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from datetime import date, timedelta
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parent.parent
SKIP_PARTS = {".git", ".DerivedData", ".tools", ".build", "Generated", "BalanceSweepReports"}
LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
HEADING = re.compile(r"^(#{1,6})\s+(.+?)(?:\s+#*)?\s*$")
FENCE = re.compile(r"^(`{3,}|~{3,})")
PLAN_STATUSES = {"active", "blocked", "complete", "cancelled"}
ARCHIVED_PLAN_STATUSES = {"complete", "cancelled"}
PLAN_WARNING_DAYS = 3
DOC_WARNINGS: list[str] = []
SOURCE_GREP_PATHS = ("Packages", "Trinket", "Scripts", "project.yml")


def markdown_files() -> list[Path]:
    """Return tracked and untracked authored Markdown while respecting ignores."""
    result = subprocess.run(
        [
            "git",
            "-C",
            str(ROOT),
            "ls-files",
            "--cached",
            "--",
            "*.md",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode == 0:
        authored = set(result.stdout.splitlines())
        untracked = subprocess.run(
            [
                "git",
                "-C",
                str(ROOT),
                "ls-files",
                "--others",
                "--exclude-standard",
                "--",
                "*.md",
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        if untracked.returncode == 0:
            authored.update(untracked.stdout.splitlines())
        return sorted(
            ROOT / line
            for line in authored
            if line
            and not SKIP_PARTS.intersection(Path(line).parts)
            and (ROOT / line).is_file()
        )

    # Keep the checker usable from a source export without a Git metadata
    # directory. The normal repository path above is deliberately narrower.
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


def plan_metadata(path: Path) -> tuple[dict[str, str], list[str]]:
    """Parse the deliberately small plan front matter without a YAML dependency."""
    lines = path.read_text(encoding="utf-8").splitlines()
    errors: list[str] = []
    if not lines or lines[0].strip() != "---":
        return {}, ["missing front matter"]
    try:
        end = lines.index("---", 1)
    except ValueError:
        return {}, ["front matter is not closed"]
    metadata: dict[str, str] = {}
    for line in lines[1:end]:
        if not line.strip():
            continue
        match = re.fullmatch(r"([A-Za-z][A-Za-z0-9_-]*):[ \t]*(.+)", line)
        if match is None:
            errors.append(f"invalid metadata line {line!r}")
            continue
        metadata[match.group(1)] = match.group(2).strip()
    for key in ("type", "status", "created", "updated", "expires"):
        if not metadata.get(key):
            errors.append(f"missing {key}")
    if metadata.get("type") and metadata["type"] != "execution-plan":
        errors.append("type must be execution-plan")
    status = metadata.get("status", "")
    if status and status not in PLAN_STATUSES:
        errors.append(f"status must be one of {', '.join(sorted(PLAN_STATUSES))}")
    if status == "blocked" and not metadata.get("reason"):
        errors.append("blocked plans require reason")
    parsed_dates: dict[str, date] = {}
    for key in ("created", "updated", "expires"):
        value = metadata.get(key, "")
        if not value:
            continue
        try:
            parsed_dates[key] = date.fromisoformat(value)
        except ValueError:
            errors.append(f"{key} must be an ISO date")
    if parsed_dates.get("created") and parsed_dates.get("updated") and parsed_dates["updated"] < parsed_dates["created"]:
        errors.append("updated must not precede created")
    if (
        status not in ARCHIVED_PLAN_STATUSES
        and parsed_dates.get("updated")
        and parsed_dates.get("expires")
        and parsed_dates["expires"] <= parsed_dates["updated"]
    ):
        errors.append("expires must be later than updated")
    return metadata, errors


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


def structural_checks(files: list[Path], *, final: bool = False, keep_plan: bool = False) -> list[str]:
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
    registry = set()
    for line in (ROOT / "Scripts" / "config" / "smoke-classes.txt").read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if "=" not in stripped or not stripped.split("=", 1)[1].strip():
            failures.append(f"Scripts/config/smoke-classes.txt: malformed line (expected KEY=Class): {stripped}")
            continue
        registry.add(stripped.split("=", 1)[1])
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

    # FullUI coverage guard: every UI test class outside Smoke/ and Performance/
    # must be selected in FullUI.xctestplan, and every FullUI class must appear
    # in the exhaustive-ui CI matrix. Plans use `automaticallyIncludesTests:
    # false`, so a new class is silently skipped everywhere without this check.
    fullui_plan = json.loads((ROOT / "FullUI.xctestplan").read_text(encoding="utf-8"))
    fullui_selected = {
        test
        for target in fullui_plan["testTargets"]
        for test in target.get("selectedTests", [])
    }
    routable_classes: set[str] = set()
    for path in sorted((ROOT / "TrinketUITests").rglob("*.swift")):
        parts = path.relative_to(ROOT).parts
        if any(part in {"Smoke", "Performance", "Support"} for part in parts):
            continue
        routable_classes.update(
            name
            for name in re.findall(
                r"(?:final\s+)?class\s+(\w+)\s*:\s*(?:SeededSmokeUITestCase|TrinketUITestCase)",
                path.read_text(encoding="utf-8"),
            )
            if name.endswith("Tests")
        )
    missing_fullui = sorted(routable_classes - fullui_selected)
    if missing_fullui:
        failures.append(
            "FullUI.xctestplan is missing UI test classes "
            f"{missing_fullui} (add them to the plan or move the files under Smoke/ or Performance/)"
        )
    ci_workflow_text = (ROOT / ".github" / "workflows" / "tests.yml").read_text(encoding="utf-8")
    missing_ci = sorted(name for name in fullui_selected if name not in ci_workflow_text)
    if missing_ci:
        failures.append(
            f".github/workflows/tests.yml exhaustive-ui matrix is missing FullUI classes: {missing_ci}"
        )

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

    plans_dir = ROOT / "Docs" / "Plans"
    archived_dir = plans_dir / "Archived"
    parallel_plan_paths = sorted((ROOT / ".agents" / "plans").glob("*.md"))
    parallel_plan_paths.extend(
        path
        for path in files
        if path.is_file()
        and plans_dir not in path.parents
        and "type: execution-plan" in path.read_text(encoding="utf-8", errors="replace")
    )
    for path in sorted(set(parallel_plan_paths)):
        failures.append(
            f"{path.relative_to(ROOT)}: execution plans are allowed only directly under Docs/Plans/"
        )
    archived_plan_files = sorted(path for path in archived_dir.glob("*.md") if path.name != "README.md")
    for path in archived_plan_files:
        failures.append(
            f"{path.relative_to(ROOT)}: completed plan detail belongs in Git history; "
            "record one outcome row in Docs/Plans/Archived/README.md"
        )
    active_plans = 0
    plan_paths = sorted(plans_dir.glob("*.md"))
    for plan_path in plan_paths:
        if plan_path.name == "README.md":
            continue
        metadata, errors = plan_metadata(plan_path)
        relative_plan = plan_path.relative_to(ROOT)
        if errors:
            failures.append(f"{relative_plan}: " + "; ".join(errors))
            continue
        status = metadata["status"]
        if status in ARCHIVED_PLAN_STATUSES:
            failures.append(
                f"{relative_plan}: {status} plans must be summarized in Docs/Plans/Archived/README.md and deleted"
            )
            continue
        try:
            expires = date.fromisoformat(metadata["expires"])
        except ValueError:
            continue
        today = date.today()
        if expires <= today:
            failures.append(
                f"{relative_plan}: {status} plan expired on {expires}; update or renew it, or record its outcome in Docs/Plans/Archived/README.md and delete it"
            )
        elif expires <= today + timedelta(days=PLAN_WARNING_DAYS):
            DOC_WARNINGS.append(
                f"{relative_plan}: {status} plan expires on {expires}; renew or close it"
            )
        if status == "active":
            active_plans += 1
            if final and not keep_plan:
                failures.append(
                    f"{relative_plan}: active plan remains at final handoff; record its outcome in Docs/Plans/Archived/README.md and delete it, or pass --keep-plan"
                )
    if active_plans > 3:
        DOC_WARNINGS.append(f"Docs/Plans/: {active_plans} active plans are present")
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
