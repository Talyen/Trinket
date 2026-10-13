#!/usr/bin/env python3
"""Select audited leaf-script regression families; unknown/shared inputs run all."""

from __future__ import annotations

import argparse
from fnmatch import fnmatchcase
from pathlib import Path

from internal.cli import ROOT, validate_repo_paths

# Explicit full-suite exceptions take precedence over the ownership registry.
# test_script_selection.py requires every other Scripts/ leaf to have an owner.
INTENTIONALLY_UNMAPPED = {
    "Scripts/internal/cli.py": "shared CLI and file helpers; a narrow route would miss consumers",
    "Scripts/test-scripts.sh": "the runner itself; self-hosted, always full suite",
    "Scripts/config/script-regressions.tsv": "shared regression ownership; verify all consumers",
    ".github/workflows/tests.yml": "shared test orchestration; declared consumers cannot narrow its coverage",
}
# Product inputs have their own handoff gates. A regression may still claim one
# explicitly in the registry, which takes precedence over this exclusion.
PRODUCT_ROOTS = frozenset({
    "Packages", "Trinket", "TrinketUITests", "ContentManifest", "ArtManifest",
    "MusicManifest", "SoundManifest", "Raw Assets",
    "StoreKit", "Performance",
})
REGISTRY = "Scripts/config/script-regressions.tsv"


def regression_families(root: Path = ROOT) -> list[tuple[set[str], set[str]]]:
    """Read the shared dependency registry without importing test modules."""
    families = []
    seen: set[str] = set()
    try:
        for number, line in enumerate((root / REGISTRY).read_text().splitlines(), 1):
            if not line.strip() or line.startswith("#"):
                continue
            columns = line.split("\t")
            if len(columns) != 2:
                raise ValueError(f"line {number}: expected input and suites separated by one tab")
            owner, names = columns
            if (not owner or owner != owner.strip() or Path(owner).is_absolute()
                    or ".." in Path(owner).parts or (root / owner).is_dir()):
                raise ValueError(f"line {number}: invalid input path: {owner!r}")
            if owner in seen:
                raise ValueError(f"line {number}: duplicate input: {owner}")
            seen.add(owner)
            modules = names.split(",")
            if len(modules) != len(set(modules)) or any(
                Path(name).name != name or name != name.strip() or not (
                    name.startswith("test") and name.endswith(".py")
                    or name.startswith("test-") and name.endswith(".sh")
                ) for name in modules
            ):
                raise ValueError(f"line {number}: expected unique test suite basenames")
            families.append(({owner}, {f"Scripts/Tests/{name}" for name in modules}))
    except (OSError, ValueError) as error:
        raise ValueError(f"{REGISTRY}: invalid test ownership: {error}") from error
    return families


def select_tests(paths: list[str], root: Path = ROOT) -> list[str]:
    available = sorted(
        path.relative_to(root).as_posix()
        for path in (root / "Scripts/Tests").iterdir()
        if (path.name.startswith("test") and path.suffix == ".py")
        or (path.name.startswith("test-") and path.suffix == ".sh")
    )
    if not paths:
        return available
    # Validate the complete scope before a full-suite fallback can short-circuit it.
    paths = [Path(path).as_posix() for path in paths]
    if any(Path(path).is_absolute() for path in paths):
        raise ValueError("--paths requires repository-relative files")
    validate_repo_paths(paths, root)
    routes = regression_families(root)
    available_set = set(available)
    selected: set[str] = set()
    for path in paths:
        if path.endswith(".md"):
            continue
        if path in INTENTIONALLY_UNMAPPED:
            return available
        # Editing a regression module runs just itself.
        if path in available_set:
            selected.add(path)
            continue
        families = [modules for owners, modules in routes
                    if any(fnmatchcase(path, owner) for owner in owners)]
        if not families:
            if path.partition("/")[0] in PRODUCT_ROOTS:
                continue
            return available
        for modules in families:
            selected.update(modules)
    missing = selected - available_set
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
