#!/usr/bin/env python3
"""Shared scaffolding for Scripts/ Python tools.

Single source for the repo-root discovery, usage-error reporting, shell-env
array parsing, and sibling-module loading previously copy-pasted across the
check-*/agent-*/performance helpers.

Scripts run as `python3 Scripts/<tool>.py`, so each tool still needs one
bootstrap line before importing this module::

    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from internal.cli import ROOT, die, load_sibling, read_env_arrays
"""

from __future__ import annotations

import importlib.util
import shlex
import sys
from pathlib import Path
from typing import NoReturn


def repo_root() -> Path:
    """Repository root derived from this file's location (Scripts/internal/)."""
    return Path(__file__).resolve().parent.parent.parent


ROOT = repo_root()


def die(message: str, usage: str = "", code: int = 1) -> NoReturn:
    """Print a usage error to stderr and exit. Replaces ad-hoc prints."""
    if message:
        print(message, file=sys.stderr)
    if usage:
        print(usage, file=sys.stderr)
    raise SystemExit(code)


def load_sibling(name: str, filename: str) -> object:
    """Load a hyphenated Scripts/ module by filename (replaces per-file importlib)."""
    path = Path(__file__).resolve().parent.parent / filename
    if not path.is_file():
        raise RuntimeError(f"Unable to load {filename}")
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to load {filename}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def read_env_arrays(path: Path | str, names: list[str]) -> dict[str, tuple[str, ...]]:
    """Parse `NAME=( ... )` bash array assignments from a sourced env file.

    Handles single/double quoting via shlex; entries with live shell
    expansions (`$`, backticks, `$(`) are rejected so a Python parse can
    never silently disagree with bash sourcing.
    """
    wanted = set(names)
    found: dict[str, list[str]] = {}
    current: str | None = None
    buffer: list[str] = []
    for raw_line in Path(path).read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if current is None:
            for name in wanted:
                if line == f"{name}=(" or line.startswith(f"{name}=("):
                    rest = line[len(name) + 2 :].strip()
                    current = name
                    buffer = []
                    if rest:
                        line = rest
                    else:
                        break
                    if line.endswith(")"):
                        chunk = line[:-1].strip()
                        if chunk:
                            buffer.append(chunk)
                        found[current] = _split_array(" ".join(buffer), path, current)
                        current = None
                    elif line:
                        buffer.append(line)
                    break
        elif line.endswith(")"):
            chunk = line[:-1].strip()
            if chunk:
                buffer.append(chunk)
            assert current is not None
            found[current] = _split_array(" ".join(buffer), path, current)
            current = None
        else:
            buffer.append(line)
    if current is not None:
        raise ValueError(f"{path}: unterminated array {current}")
    missing = wanted - set(found)
    if missing:
        raise ValueError(f"{path}: missing arrays: {', '.join(sorted(missing))}")
    return {name: tuple(found[name]) for name in names}


def _split_array(body: str, path: Path | str, name: str) -> list[str]:
    # Entries are literal paths; any `$`/backtick means live shell expansion
    # that Python must not silently misread — source it in bash instead.
    if "$" in body or "`" in body:
        raise ValueError(f"{path}: array {name} needs live shell expansion; source it in bash instead")
    return shlex.split(body)


def validate_repo_paths(paths: list[str], root: Path = ROOT) -> list[str]:
    """Validate --paths input: individual files inside the repository.

    Accepts repository-relative paths and absolute paths that resolve inside
    the repository (historical checkers accepted both); rejects directories,
    escapes, and missing values are left to the caller. Raises ValueError
    (callers surface via argparse error / exit 2) instead of each tool
    restating the checks.
    """
    validated: list[str] = []
    resolved_root = root.resolve()
    for raw in paths:
        candidate = Path(raw)
        if ".." in candidate.parts:
            raise ValueError("--paths requires repository-relative files")
        resolved = candidate.resolve() if candidate.is_absolute() else (root / candidate).resolve()
        try:
            resolved.relative_to(resolved_root)
        except ValueError:
            raise ValueError(f"--paths requires individual files inside the repository: {raw}") from None
        if resolved.is_dir():
            raise ValueError(f"--paths requires individual files inside the repository: {raw}")
        validated.append(raw)
    return validated
