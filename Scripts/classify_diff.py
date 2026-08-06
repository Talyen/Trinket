#!/usr/bin/env python3
"""Shared git-diff plumbing for the fail-closed diff classifiers."""

from __future__ import annotations

import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def git_diff(path: str) -> str:
    result = subprocess.run(
        ["git", "diff", "HEAD", "--", path],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    return result.stdout


def is_tracked(path: str) -> bool:
    result = subprocess.run(
        ["git", "ls-files", "--error-unmatch", "--", path],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    return result.returncode == 0


def changed_lines(diff: str) -> list[str]:
    lines: list[str] = []
    for raw in diff.splitlines():
        if raw.startswith("+++ ") or raw.startswith("--- "):
            continue
        if raw.startswith("+") or raw.startswith("-"):
            lines.append(raw[1:])
    return lines
