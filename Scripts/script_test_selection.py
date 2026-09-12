#!/usr/bin/env python3
"""Select audited leaf-script regression families; unknown/shared inputs run all."""

from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Keep each leaf with its consumers' regressions. Infrastructure, runners,
# fixtures, and this selector intentionally have no narrow route.
FAMILIES = (
    (
        {"Scripts/agent-search.py"},
        {"test_agent_search"},
    ),
    (
        {"Scripts/check-links.py", "Scripts/check-docs.py", "Scripts/check-plans.py",
         "Scripts/check-testplan-sync.py", "Scripts/agent-read.py", "Scripts/internal/markdown.py"},
        {"test_documentation"},
    ),
    (
        {"Scripts/aggregate-performance-results.py", "Scripts/compare-performance.py",
         "Scripts/collect-performance-results.py", "Scripts/internal/performance/performance_model.py",
         "Scripts/performance_environment.py"},
        {"test_aggregate_performance", "test_compare_performance", "test_exec_wrappers"},
    ),
    (
        {"Scripts/release-notes-user.py"},
        {"test_release_notes_user"},
    ),
)


def select_tests(paths: list[str], root: Path = ROOT) -> list[str]:
    available = sorted(
        path.relative_to(root).as_posix()
        for path in (root / "Scripts/Tests").iterdir()
        if (path.name.startswith("test") and path.suffix == ".py")
        or (path.name.startswith("test-") and path.suffix == ".sh")
    )
    if not paths:
        return available
    selected: set[str] = set()
    for raw in paths:
        path = Path(raw).as_posix()
        if Path(path).is_absolute() or ".." in Path(path).parts:
            raise ValueError("--paths requires repository-relative files")
        if (root / path).is_dir():
            raise ValueError("--paths requires individual files, not directories")
        if path.endswith(".md"):
            continue
        families = [modules for owners, modules in FAMILIES if path in owners]
        if not families:
            return available
        for modules in families:
            selected.update(f"Scripts/Tests/{module}.py" for module in modules)
    missing = selected - set(available)
    if missing:
        raise ValueError(f"selected regression modules are missing: {', '.join(sorted(missing))}")
    return sorted(selected)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--paths", nargs="+", default=[])
    args = parser.parse_args()
    try:
        print("\n".join(select_tests(args.paths)))
    except ValueError as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
