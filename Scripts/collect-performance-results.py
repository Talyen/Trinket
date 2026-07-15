#!/usr/bin/env python3
"""Collect one-line Battle performance JSON records from xcodebuild logs."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

MARKER = "TRINKET_PERFORMANCE_REPORT "


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("results_dir", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    records: list[dict[str, object]] = []
    seen: set[str] = set()
    for path in sorted(args.results_dir.rglob("*.log")):
        for line in path.read_text(errors="replace").splitlines():
            marker_index = line.find(MARKER)
            if marker_index < 0:
                continue
            payload = line[marker_index + len(MARKER) :].strip()
            try:
                record = json.loads(payload)
            except json.JSONDecodeError:
                continue
            key = json.dumps(record, sort_keys=True)
            if key in seen:
                continue
            seen.add(key)
            record["sourceLog"] = str(path.relative_to(args.results_dir))
            records.append(record)

    records.sort(key=lambda item: (str(item.get("scenario")), int(item.get("iteration", 0))))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({"reports": records}, indent=2, sort_keys=True) + "\n")
    print(f"Collected {len(records)} Battle performance reports into {args.output}")
    return 0 if records else 1


if __name__ == "__main__":
    raise SystemExit(main())
