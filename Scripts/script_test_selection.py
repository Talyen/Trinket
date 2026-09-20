#!/usr/bin/env python3
"""Select audited leaf-script regression families; unknown/shared inputs run all."""

from __future__ import annotations

import argparse
import ast
from fnmatch import fnmatchcase
from pathlib import Path

from internal.cli import ROOT

# Keep each leaf with its consumers' regressions. Infrastructure, runners,
# and shared fixtures without declared ownership use the full-suite fallback.
#
# INTENTIONALLY_UNMAPPED names leaves that must keep the safe full-suite
# fallback (with the reason); test_script_selection.py enforces that every
# other Scripts/ leaf is owned by suite metadata or the shell families below.
INTENTIONALLY_UNMAPPED = {
    "Scripts/internal/cli.py": "shared by six families; any narrow route would under-test consumers",
    "Scripts/test-scripts.sh": "the runner itself; self-hosted, always full suite",
}
SHELL_FAMILIES = (({'Scripts/build-for-testing.sh',
   'Scripts/build-freshness.sh',
   'Scripts/build.sh',
   'Scripts/check-build-cache-paths.sh',
   'Scripts/format.sh',
   'Scripts/lib/app-build.sh',
   'Scripts/lib/args.sh',
   'Scripts/lib/derived-data.sh',
   'Scripts/lib/tempdir.sh',
   'Scripts/lib/test-helpers.sh',
   'Scripts/lib/test-style.sh',
   'Scripts/lint-analyze.sh',
   'Scripts/lint.sh',
   'Scripts/prune-derived-data-cache.sh',
   'Scripts/stage-ci-test-artifact.sh',
   'Scripts/test-package.sh',
   'Scripts/test.sh'},
  {'test-lib-args.sh', 'test-lib-tempdir.sh'}),
 ({'Scripts/ci-gate.sh',
   'Scripts/config/cheap-slices.txt',
   'Scripts/handoff.sh',
   'Scripts/lib/args.sh',
   'Scripts/lib/cheap-slices.sh',
   'Scripts/lib/gate.sh'},
  {'test-lib-args.sh'}),
 ({'Scripts/ci-assets-gate.sh',
   'Scripts/lib/media-assets.sh',
   'Scripts/prepare-app-icon.sh',
   'Scripts/prepare-art-assets.sh',
   'Scripts/prepare-assets.sh',
   'Scripts/prepare-audio-assets.sh',
   'Scripts/prepare-cinematic-assets.sh',
   'Scripts/report-art-memory.sh'},
  {'test-asset-hash-sort-locale.sh'}),
 ({'Scripts/config/simulator-names.env',
   'Scripts/ensure-simulator.sh',
   'Scripts/lib/lock.sh',
   'Scripts/lib/simctl.sh',
   'Scripts/lib/slots.sh',
   'Scripts/run-env.sh',
   'Scripts/simctl_json.py'},
  {'test-run-env.sh'}),
 ({'Scripts/config/infrastructure-patterns.env',
   'Scripts/lib/infrastructure-patterns.sh',
   'Scripts/lib/xcode-manifest.sh',
   'Scripts/lib/xcode-watchdog.sh',
   'Scripts/lib/xcodebuild-infra.sh',
   'Scripts/xcode-runner.sh'},
  {'test-xcode-runner.sh'}))


def _module_path(module: str) -> str:
    if module.endswith(".sh"):
        return f"Scripts/Tests/{module}"
    return f"Scripts/Tests/{module}.py"


def regression_families(root: Path = ROOT) -> list[tuple[set[str], set[str]]]:
    """Read literal SCRIPT_INPUTS without importing or executing test modules."""
    families = list(SHELL_FAMILIES)
    for path in sorted((root / "Scripts/Tests").glob("test*.py")):
        try:
            tree = ast.parse(path.read_text(), filename=str(path))
            declarations = [node for node in tree.body if isinstance(node, ast.Assign)
                            and any(isinstance(target, ast.Name) and target.id == "SCRIPT_INPUTS"
                                    for target in node.targets)]
            if not declarations:
                continue
            if len(declarations) != 1:
                raise ValueError("SCRIPT_INPUTS must be declared once")
            inputs = ast.literal_eval(declarations[0].value)
            if not isinstance(inputs, (tuple, list)) or not all(isinstance(value, str) for value in inputs):
                raise ValueError("SCRIPT_INPUTS must be a literal tuple/list of repository-relative paths or globs")
            for value in inputs:
                if not value or Path(value).is_absolute() or ".." in Path(value).parts:
                    raise ValueError(f"invalid SCRIPT_INPUTS path: {value!r}")
            families.append((set(inputs), {path.stem}))
        except (OSError, SyntaxError, ValueError, TypeError) as error:
            raise ValueError(f"{path.relative_to(root)}: invalid test ownership: {error}") from error
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
    routes = regression_families(root)
    available_set = set(available)
    selected: set[str] = set()
    for raw in paths:
        path = Path(raw).as_posix()
        if Path(path).is_absolute() or ".." in Path(path).parts:
            raise ValueError("--paths requires repository-relative files")
        if (root / path).is_dir():
            raise ValueError("--paths requires individual files, not directories")
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
            return available
        for modules in families:
            selected.update(_module_path(module) for module in modules)
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
