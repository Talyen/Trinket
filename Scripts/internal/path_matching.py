"""Explicit historical matching dialects for local routing and hosted CI."""
from fnmatch import fnmatchcase
import functools


def matches(path: str, *patterns: str) -> bool:
    """Local routing: wildcards may span path separators, as in fnmatchcase."""
    return any(fnmatchcase(path, pattern) for pattern in patterns)


def glob_match(path: str, pattern: str) -> bool:
    """CI routing: a single star stays within its component; ** spans components."""
    patterns, segments = pattern.split("/"), path.split("/")

    @functools.cache
    def match(p: int, s: int) -> bool:
        if p == len(patterns):
            return s == len(segments)
        if patterns[p] == "**":
            if p == len(patterns) - 1:
                return s < len(segments)
            return match(p + 1, s) or (s < len(segments) and match(p, s + 1))
        return s < len(segments) and fnmatchcase(segments[s], patterns[p]) and match(p + 1, s + 1)

    return match(0, 0)
