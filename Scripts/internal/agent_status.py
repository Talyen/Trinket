"""Scoped workspace status for the agent-context shell entry point."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Change:
    status: str
    path: str
    original: str | None = None


def changes(root: Path) -> list[Change]:
    result = subprocess.check_output(
        ["git", "--no-optional-locks", "status", "--porcelain=v1", "-z", "--untracked-files=all", "--renames"],
        cwd=root,
    )
    fields = iter(result.split(b"\0"))
    entries = []
    for field in fields:
        if not field:
            continue
        if len(field) < 4 or field[2:3] != b" ":
            raise ValueError("malformed Git status record")
        status = field[:2].decode("ascii")
        original = None
        if "R" in status or "C" in status:
            original = os.fsdecode(next(fields))
            if not original:
                raise ValueError("missing rename/copy source")
        entries.append(Change(status, os.fsdecode(field[3:]), original))
    return entries


def owner(path: str) -> str:
    parts = path.split("/")
    if len(parts) == 1:
        return "(root)"
    return "/".join(parts[:2]) if len(parts) > 2 and parts[0] in {"Packages", "Docs"} else parts[0]


def display(path: str) -> str:
    return json.dumps(path, ensure_ascii=True) if any(c.isspace() or c in '\\"' or ord(c) < 32 for c in path) else path


def briefing(root: Path, paths: list[str]) -> str:
    entries = changes(root)
    counts: Counter[str] = Counter()
    selected = []
    scope = set(paths)
    for entry in entries:
        endpoints = {entry.path} | ({entry.original} if entry.original is not None else set())
        counts.update({owner(path) for path in endpoints})
        if endpoints & scope:
            selected.append(entry)
    lines = [f"Workspace status: {len(entries)} dirty entries (owner counts include both rename endpoints)"]
    lines.extend(f"  {name}: {count}" for name, count in sorted(counts.items()))
    lines.append(f"Scoped status: {len(selected)} dirty entries; {len(entries) - len(selected)} outside supplied paths")
    for entry in selected:
        path = display(entry.path)
        if entry.original is not None:
            path = f"{display(entry.original)} -> {path}"
        lines.append(f"  {entry.status} {path}")
    if not selected:
        lines.append("  (supplied paths are clean)")
    return "\n".join(lines)


if __name__ == "__main__":
    try:
        print(briefing(Path(__file__).resolve().parents[2], sys.argv[1:]))
    except (OSError, ValueError, StopIteration, subprocess.CalledProcessError) as error:
        print(f"Status failed: {error}", file=sys.stderr)
        raise SystemExit(2)
