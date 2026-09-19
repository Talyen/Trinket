#!/usr/bin/env python3
"""Summarize only this package invocation's retained worker output and reports."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from internal.diagnostics.diagnostic_limits import MAX_AGGREGATE_ISSUES, MAX_LINE_CHARS, MAX_LINES
from script_diagnostics import excerpt


def summarize(root: Path, packages: list[str], *, verbose: bool = False) -> int:
    failures = False
    issues: dict[tuple[str, str, str, str], list[str]] = {}
    fallback: list[str] = []
    for package in packages:
        status_file = root / f"{package}.status"
        status = status_file.read_text().strip() if status_file.is_file() else "missing"
        passed = status == "0"
        failures |= not passed
        print(f"{package}: {'PASS' if passed else 'FAIL'} (exit {status})")
        stdout = root / f"{package}.stdout"
        print(f"  Output: {stdout}")
        pointer = root / f"{package}.report"
        prefix = Path(pointer.read_text().strip()) if pointer.is_file() else None
        report = None
        if prefix:
            # Append: a caller's prefix may itself contain dots.
            for suffix in (".json", ".md"):
                artifact = Path(str(prefix) + suffix)
                if artifact.is_file():
                    print(f"  Report: {artifact}")
            try:
                report = json.loads(Path(str(prefix) + ".json").read_text())
            except (OSError, ValueError):
                report = None
        if verbose:
            if stdout.is_file():
                with stdout.open(errors="replace") as source:
                    for line in source:
                        print(line, end="")
            if prefix and Path(str(prefix) + ".md").is_file():
                print(Path(str(prefix) + ".md").read_text())
        if passed:
            continue
        entries = report.get("issues", []) if isinstance(report, dict) else []
        if entries:
            for issue in entries:
                # Keep distinct tests separate while collapsing the same compiler
                # error reported by several downstream package builds.
                key = (str(issue.get("file", "")), str(issue.get("line", "")),
                       str(issue.get("test", "")), str(issue.get("message", issue.get("title", ""))))
                labels = issues.setdefault(key, [])
                if package not in labels:
                    labels.append(package)
        elif stdout.is_file():
            fallback.extend(f"{package}: {line}" for line in excerpt(stdout))
        else:
            fallback.append(f"{package}: worker output unavailable")
    if not verbose:
        details = []
        for (file, line, test, message), labels in issues.items():
            details.append(f"[{', '.join(labels)}] {file}:{line} {test} {message}".strip())
        omitted_issues = max(0, len(details) - MAX_AGGREGATE_ISSUES)
        details = details[:MAX_AGGREGATE_ISSUES] + fallback
        shortened = False
        for line in details[:MAX_LINES - 1]:
            line = " ".join(line.splitlines())
            shortened |= len(line) > MAX_LINE_CHARS
            print(line[:MAX_LINE_CHARS - 1] + "…" if len(line) > MAX_LINE_CHARS else line)
        if shortened or len(details) >= MAX_LINES or omitted_issues:
            print("… additional diagnostic detail omitted; all worker output and reports are retained above.")
    return int(failures)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verbose", action="store_true")
    parser.add_argument("root", type=Path)
    parser.add_argument("packages", nargs="+")
    args = parser.parse_args()
    return summarize(args.root, args.packages, verbose=args.verbose)


if __name__ == "__main__":
    sys.exit(main())
