"""Fail-closed source search and reporting shared by lightweight policy gates."""

from __future__ import annotations

from functools import cache
import os
from pathlib import Path
import re
import subprocess
import sys

from internal.cli import pinned_tool_path


def candidates(pattern: str, paths: list[str], root: Path, *, globs: tuple[str, ...] = ('*.swift',)) -> list[Path]:
    if not paths:
        return []
    command = ['rg', '--files-with-matches', '--null']
    for glob in globs:
        command.extend(('--glob', glob))
    result = subprocess.run([*command, pattern, '--', *paths], cwd=root, capture_output=True, text=True,
                            env={**os.environ, 'PATH': pinned_tool_path(root)})
    if result.returncode not in (0, 1):
        raise RuntimeError(f'Policy search failed (rg exit {result.returncode}): {result.stderr.strip()}')
    return sorted({root / name for name in result.stdout.split('\0') if name})


class SourceScan:
    def __init__(self, root: Path):
        self.root = root

    @cache
    def text(self, path: Path) -> str:
        return path.read_text(encoding='utf-8')

    @cache
    def lines(self, path: Path) -> list[str]:
        return self.text(path).splitlines()

    def matches(self, pattern: str, *paths: str, generated: bool = False):
        regex = re.compile(pattern)
        globs = ('*.swift',) if generated else ('*.swift', '!**/Generated/**')
        for path in candidates(pattern, list(paths), self.root, globs=globs):
            for index, line in enumerate(self.lines(path)):
                if regex.search(line):
                    yield path, index, line

    def nearby(self, path: Path, index: int, pattern: str) -> bool:
        return any(re.search(pattern, line) for line in self.lines(path)[max(0, index - 4):index + 1])

    def allowed(self, path: Path, index: int, marker: str) -> bool:
        return self.nearby(path, index, rf'^\s*//\s*{marker}:\s*allow\s*-\s*\S')

    def location(self, path: Path, index: int, message: str) -> str:
        return f'{path.relative_to(self.root).as_posix()}:{index + 1}: {message}'


def report(findings: list[str], header: str, success: str, title: str = '', *footer: str, stream=None) -> int:
    if not findings:
        print(success)
        return 0
    stream = sys.stderr if stream is None else stream
    print(header, file=stream)
    for finding in findings:
        print(f'  - {finding}', file=stream)
        if title and os.environ.get('GITHUB_ACTIONS') == 'true':
            match = re.fullmatch(r'([^:]+):(?:(\d+):)?(.*)', finding)
            path, line, message = match.groups() if match else (finding, None, finding)
            print(f'::error file={path.strip()},line={line or 1},title={title}::{message.strip()}')
    for line in footer:
        print(line, file=stream)
    return 1
