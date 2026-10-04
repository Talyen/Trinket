#!/usr/bin/env python3
"""Shared scaffolding for Scripts/ Python tools.

Single source for the repo-root discovery, usage-error reporting, shell-env
array parsing, JSON loading, and sibling-module loading previously copy-pasted
across the check-*/agent-*/performance helpers.

Scripts run as `python3 Scripts/<tool>.py`, so each tool still needs one
bootstrap line before importing this module::

    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from internal.cli import ROOT, die, load_sibling, read_env_arrays, read_json
"""

from __future__ import annotations

import importlib.util
import json
import shlex
import sys
from pathlib import Path
from typing import Any, NoReturn


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


def read_json(path: Path | str) -> Any:
    """Load a JSON file, attaching the path to decode errors.

    OSError propagates unchanged (it already carries the filename); only the
    message of JSONDecodeError is prefixed so strict gates report which file
    failed. Callers that tolerate missing/corrupt input keep their own
    try/except — the exception types are unchanged.
    """
    text = Path(path).read_text(encoding="utf-8")
    try:
        return json.loads(text)
    except json.JSONDecodeError as error:
        raise json.JSONDecodeError(f"{path}: {error.msg}", error.doc, error.pos) from None


def read_env_arrays(path: Path | str, names: list[str]) -> dict[str, tuple[str, ...]]:
    """Parse `NAME=( ... )` bash array assignments from a sourced env file.

    Handles single/double quoting via shlex; entries with live shell
    expansions (`$`, backticks, `$(`) are rejected so a Python parse can
    never silently disagree with bash sourcing.
    """
    wanted = set(names)
    found: dict[str, tuple[str, ...]] = {}
    tokens = iter(_env_array_tokens(Path(path).read_text(encoding="utf-8")))
    for token in tokens:
        if token.removesuffix("+=") in wanted and token.endswith("+="):
            raise ValueError(f"{path}: appended arrays require bash sourcing")
        name = token.removesuffix("=")
        if not token.endswith("=") or name not in wanted:
            continue
        if name in found:
            raise ValueError(f"{path}: duplicate array {name}")
        if next(tokens, None) != "\0(":
            raise ValueError(f"{path}: {name} must be a literal array")
        body = []
        for entry in tokens:
            if entry == "\0)":
                break
            if entry == "\0(":
                raise ValueError(f"{path}: array {name} needs live shell expansion; source it in bash instead")
            body.append(entry)
        else:
            raise ValueError(f"{path}: unterminated array {name}")
        entries = body
        if any("$" in entry or "`" in entry for entry in entries):
            raise ValueError(f"{path}: array {name} needs live shell expansion; source it in bash instead")
        found[name] = tuple(entries)
    missing = wanted - found.keys()
    if missing:
        raise ValueError(f"{path}: missing arrays: {', '.join(sorted(missing))}")
    return {name: found[name] for name in names}


def _env_array_tokens(source: str) -> list[str]:
    # Mark only unquoted delimiters before POSIX tokenization. Non-POSIX
    # tokenization loses escaped quotes and inserts spaces between adjacent quotes.
    if "\0" in source:
        raise ValueError("Shell input cannot contain NUL")
    marked: list[str] = []
    quote = ""
    word_start = True
    index = 0
    while index < len(source):
        char = source[index]
        if char == "\\" and quote != "'" and index + 1 < len(source):
            following = source[index + 1]
            if following != "\n":
                marked.append(source[index:index + 2])
                word_start = False
            index += 2
            continue
        if not quote and char == "#" and word_start:
            end = source.find("\n", index)
            index = len(source) if end < 0 else end
            continue
        if char == quote:
            quote = ""
        elif not quote and char in "\"'":
            quote = char
        if not quote and char in "()":
            marked.append(f" \0{char} ")
            word_start = True
        else:
            marked.append(char)
            word_start = not quote and char.isspace()
        index += 1
    return shlex.split("".join(marked))


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
