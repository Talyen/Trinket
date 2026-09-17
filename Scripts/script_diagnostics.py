"""Bounded terminal excerpts for retained script-test logs."""

import re
import sys
from pathlib import Path

from internal.diagnostics.diagnostic_limits import MAX_DETAIL_LINES, MAX_LINE_CHARS, MAX_LINES

FAILURE_RE = re.compile(r"Traceback \(|\b(?:FAIL|ERROR|FAILED)\b|\w*(?:Error|Exception):|assertion|syntax error", re.I)
# Multi-GB xcodebuild logs must not be read whole: scan at most the tail,
# which is where failures (and the no-match fallback window) live.
MAX_LOG_BYTES = 4 * 1024 * 1024


def _read_tail_lines(log: Path) -> tuple[list[str], bool]:
    with log.open("rb") as handle:
        handle.seek(0, 2)
        size = handle.tell()
        truncated = size > MAX_LOG_BYTES
        handle.seek(max(0, size - MAX_LOG_BYTES))
        if truncated:
            handle.readline()
        text = handle.read().decode("utf-8", errors="replace")
    return text.splitlines(), truncated


def excerpt(log: Path) -> list[str]:
    lines, truncated_input = _read_tail_lines(log)
    selected: set[int] = set()
    for index, line in enumerate(lines):
        if FAILURE_RE.search(line):
            selected.update(range(max(0, index - 2), min(len(lines), index + MAX_DETAIL_LINES + 1)))
    budget = MAX_LINES - 1
    indices = sorted(selected)[:budget] if selected else list(range(max(0, len(lines) - budget), len(lines)))
    output = []
    shortened = False
    for index in indices:
        line = f"{index + 1}: {lines[index]}"
        shortened |= len(line) > MAX_LINE_CHARS
        output.append(line if len(line) <= MAX_LINE_CHARS else line[:MAX_LINE_CHARS - 1] + "…")
    if len(indices) < len(lines) or shortened or truncated_input:
        output.append("… output omitted; full log retained at the path above.")
    return output


if __name__ == "__main__":
    print("\n".join(excerpt(Path(sys.argv[1]))), file=sys.stderr)
