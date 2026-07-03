#!/usr/bin/env python3
"""Add public access to top-level types and their direct members for TrinketCore."""

from __future__ import annotations

import re
import sys
from pathlib import Path

TOP_LEVEL = re.compile(r"^(?P<kind>enum|struct|class|actor|extension)\s+")
MEMBER = re.compile(
    r"^(?P<indent>\s{4})(?!(public |private |fileprivate |internal |open |case ))"
    r"(?P<body>(?:mutating )?(?:nonisolated )?(?:static )?(?:init|let|var|func|subscript)(?:\s|\())"
)
NESTED_TYPE = re.compile(
    r"^(?P<indent>\s{4})(?!(public |private |fileprivate |internal |open ))"
    r"(?P<body>(?:enum|struct|class|actor) )"
)


def publicize(text: str) -> str:
    lines = text.splitlines()
    out: list[str] = []
    depth = 0
    in_public_type = False

    for line in lines:
        if depth == 0:
            if TOP_LEVEL.match(line) and not line.startswith("public "):
                line = f"public {line}"
                in_public_type = True
            elif line.startswith("public extension "):
                in_public_type = True
            elif line.startswith("extension ") and not line.startswith("public "):
                line = f"public {line}"
                in_public_type = True
            else:
                in_public_type = False

        if in_public_type and depth == 1:
            match = MEMBER.match(line) or NESTED_TYPE.match(line)
            if match:
                rest = line.lstrip()
                line = f"{match.group('indent')}public {rest}"

        out.append(line)
        depth = max(0, depth + line.count("{") - line.count("}"))

    return "\n".join(out) + "\n"


def main() -> int:
    for path_str in sys.argv[1:]:
        path = Path(path_str)
        path.write_text(publicize(path.read_text()))
        print(f"publicized {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
