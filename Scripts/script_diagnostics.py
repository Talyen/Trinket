"""Bounded terminal excerpts for retained script-test logs."""

import re
import sys
from pathlib import Path

from diagnostic_limits import MAX_DETAIL_LINES, MAX_LINE_CHARS, MAX_LINES


def excerpt(log: Path) -> list[str]:
    lines = log.read_text(encoding="utf-8", errors="replace").splitlines()
    selected: set[int] = set()
    for index, line in enumerate(lines):
        if re.search(r"Traceback \(|\b(?:FAIL|ERROR|FAILED)\b|\w*(?:Error|Exception):|assertion|syntax error", line, re.I):
            selected.update(range(max(0, index - 2), min(len(lines), index + MAX_DETAIL_LINES + 1)))
    budget = MAX_LINES - 1
    indices = sorted(selected)[:budget] if selected else list(range(max(0, len(lines) - budget), len(lines)))
    output = []
    shortened = False
    for index in indices:
        line = f"{index + 1}: {lines[index]}"
        shortened |= len(line) > MAX_LINE_CHARS
        output.append(line if len(line) <= MAX_LINE_CHARS else line[:MAX_LINE_CHARS - 1] + "…")
    if len(indices) < len(lines) or shortened:
        output.append("… output omitted; full log retained at the path above.")
    return output


if __name__ == "__main__":
    print("\n".join(excerpt(Path(sys.argv[1]))), file=sys.stderr)
