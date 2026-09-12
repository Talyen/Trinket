#!/usr/bin/env python3
"""Check execution-plan lifecycle under Docs/Plans/."""

from __future__ import annotations

import argparse
import re
import sys
from datetime import date, timedelta
from pathlib import Path
import importlib.util

ROOT = Path(__file__).resolve().parent.parent
PLAN_STATUSES = {"active", "blocked", "complete", "cancelled"}
ARCHIVED_PLAN_STATUSES = {"complete", "cancelled"}
PLAN_WARNING_DAYS = 3
DOC_WARNINGS: list[str] = []


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
        and parsed_dates.get("created")
        and parsed_dates.get("expires")
        and parsed_dates["expires"] <= parsed_dates["created"]
    ):
        errors.append("expires must be later than created")
    return metadata, errors


def plan_failures(
    files: list[Path], *, final: bool = False, keep_plan: bool = False,
    paths: set[Path] | None = None,
) -> list[str]:
    failures: list[str] = []
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
            DOC_WARNINGS.append(
                f"{relative_plan}: {status} plan expired on {expires}; review its disposition when resuming this work"
            )
        elif expires <= today + timedelta(days=PLAN_WARNING_DAYS):
            DOC_WARNINGS.append(
                f"{relative_plan}: {status} plan expires on {expires}; review its disposition when resuming this work"
            )
        if status == "active":
            active_plans += 1
            if final and not keep_plan and (paths is None or plan_path.resolve() in paths):
                failures.append(
                    f"{relative_plan}: active plan remains at final handoff; record its outcome in Docs/Plans/Archived/README.md and delete it, or pass --keep-plan"
                )
    if active_plans > 3:
        DOC_WARNINGS.append(f"Docs/Plans/: {active_plans} active plans are present")
    return failures


def parse_arguments(description: str) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument("--final", action="store_true", help="require active plans in scope to be closed")
    parser.add_argument("--keep-plan", action="store_true", help="allow intentionally unfinished active plans")
    parser.add_argument("--paths", nargs="+", help="scope final closure checks to individual repository files; other checks remain global")
    args = parser.parse_args()
    if args.paths is not None:
        paths = set()
        for value in args.paths:
            path = (ROOT / value).resolve()
            if not path.is_relative_to(ROOT.resolve()) or path.is_dir():
                parser.error(f"--paths requires individual files inside the repository: {value}")
            paths.add(path)
        args.paths = paths
    return args


def main() -> int:
    args = parse_arguments(__doc__)
    links_path = Path(__file__).resolve().parent / "check-links.py"
    links_spec = importlib.util.spec_from_file_location("check_links", links_path)
    if links_spec is None or links_spec.loader is None:
        print("check-plans: unable to load check-links.py", file=sys.stderr)
        return 2
    check_links = importlib.util.module_from_spec(links_spec)
    sys.modules["check_links"] = check_links
    links_spec.loader.exec_module(check_links)

    DOC_WARNINGS.clear()
    files = check_links.markdown_files()
    failures = plan_failures(files, final=args.final, keep_plan=args.keep_plan, paths=args.paths)
    if failures:
        print("Execution plan checks failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1
    print(f"Execution plan checks passed ({len(files)} Markdown files).")
    for warning in DOC_WARNINGS:
        print(f"Warning: {warning}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
