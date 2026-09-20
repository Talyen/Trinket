"""Bounded documentation failures with complete, independently readable reports."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import sys
import tempfile

from internal.cli import ROOT


def group_failures(failures: list[str]) -> list[tuple[str, list[str]]]:
    groups: dict[str, list[str]] = {}
    for failure in failures:
        match = re.match(r"(.+?):\d+: missing link target (.+)$", failure)
        if match:
            source, target = match.groups()
            cause = "missing link target " + os.path.normpath(str(Path(source).parent / target))
        else:
            match = re.match(r"(.+?):\d+: missing heading (.+)$", failure)
            cause = "missing heading " + match.group(2) if match else failure
        groups.setdefault(cause, []).append(failure)
    return list(groups.items())


def render(failures: list[str], *, offset: int = 0, limit: int = 20, full: bool = False) -> int:
    groups = group_failures(failures)
    stop = min(len(groups), offset + limit)
    print(f"{len(failures)} failures in {len(groups)} groups; groups {offset}:{stop}.", file=sys.stderr)
    for cause, entries in groups[offset:stop]:
        title = cause if full or len(cause) <= 240 else cause[:240] + "… [shortened]"
        print(f"- {title} ({len(entries)} occurrences)", file=sys.stderr)
        for entry in entries if full else entries[:2]:
            detail = entry if full or len(entry) <= 240 else entry[:240] + "… [shortened]"
            print(f"    {detail}", file=sys.stderr)
        if not full and len(entries) > 2:
            print(f"    … {len(entries) - 2} additional locations in the report", file=sys.stderr)
    print(f"Omitted {len(groups) - stop} groups after this page.", file=sys.stderr)
    return stop


def report_failures(title: str, failures: list[str], *, root: Path = ROOT) -> None:
    print(title, file=sys.stderr)
    stop = render(failures)
    try:
        directory = Path(os.environ.get("RESULTS_DIR", str(root / ".DerivedData/DocumentationResults")))
        directory.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", prefix="docs-", suffix=".json",
                                         dir=directory, delete=False) as handle:
            json.dump({"title": title, "failures": failures}, handle, ensure_ascii=False, indent=2)
            path = Path(handle.name).resolve()
        print(f"Complete report: {path}", file=sys.stderr)
        command = ["python3", "-m", "internal.doc_diagnostics", str(path)]
        if stop < len(group_failures(failures)):
            print("Next groups: PYTHONPATH=Scripts " + shlex.join([*command, "--offset", str(stop)]), file=sys.stderr)
        print("Expand locations: PYTHONPATH=Scripts " + shlex.join([*command, "--full"]), file=sys.stderr)
    except OSError as error:
        print(f"Could not retain complete report: {error}; rerun after restoring report-directory access.", file=sys.stderr)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--offset", type=int, default=0)
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument("--full", action="store_true", help="complete locations and text for the selected groups")
    args = parser.parse_args()
    if args.offset < 0 or args.limit < 1:
        parser.error("--offset must be nonnegative and --limit positive")
    payload = json.loads(args.report.read_text(encoding="utf-8"))
    stop = render(payload["failures"], offset=args.offset, limit=args.limit, full=args.full)
    if stop < len(group_failures(payload["failures"])):
        command = ["python3", "-m", "internal.doc_diagnostics", str(args.report), "--offset", str(stop), "--limit", str(args.limit)]
        if args.full:
            command.append("--full")
        print("Continue: PYTHONPATH=Scripts " + shlex.join(command), file=sys.stderr)


if __name__ == "__main__":
    main()
