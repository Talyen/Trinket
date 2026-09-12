"""Markdown heading ranges shared by documentation links and focused reads."""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

HEADING = re.compile(r"^ {0,3}(#{1,6})\s+(.+?)(?:\s+#+)?\s*$")
FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")


def unfenced_lines(lines: list[str]):
    fence = ""
    for number, line in enumerate(lines, 1):
        match = FENCE.match(line)
        if fence:
            if match and match[1][0] == fence[0] and len(match[1]) >= len(fence) and not match[2].strip():
                fence = ""
            continue
        if match and not (match[1][0] == "`" and "`" in match[2]):
            fence = match[1]
            continue
        yield number, line


def github_slug(heading: str) -> str:
    text = re.sub(r"[^\w\s-]", "", heading.strip().lower(), flags=re.UNICODE)
    return re.sub(r"[-\s]+", "-", text).strip("-")


@dataclass
class Heading:
    title: str
    slug: str
    level: int
    start: int
    end: int
    parents: tuple[int, ...]


def headings(lines: list[str]) -> list[Heading]:
    result: list[Heading] = []
    stack: list[int] = []
    used: set[str] = set()
    for number, line in unfenced_lines(lines):
        match = HEADING.match(line)
        if match is None:
            continue
        level, title = len(match[1]), match[2]
        while stack and result[stack[-1]].level >= level:
            result[stack.pop()].end = number - 1
        base = github_slug(title)
        slug, suffix = base, 0
        while slug in used:
            suffix += 1
            slug = f"{base}-{suffix}"
        used.add(slug)
        result.append(Heading(title, slug, level, number, len(lines), tuple(stack)))
        stack.append(len(result) - 1)
    return result


def heading_slugs(path: Path) -> set[str]:
    return {heading.slug for heading in headings(path.read_text(encoding="utf-8").splitlines())}
