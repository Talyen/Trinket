#!/usr/bin/env python3
"""Append bounded preparation timings without parsing large Xcode transcripts."""
import argparse
import os
from pathlib import Path
import time
from datetime import datetime, timezone
from internal.output_retention import update_timing


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("begin")
    end = commands.add_parser("end")
    end.add_argument("phase")
    end.add_argument("started", type=int)
    end.add_argument("scope")
    args = parser.parse_args(argv)
    now = time.monotonic_ns()
    if args.command == "begin":
        print(now)
        return
    if not 0 <= args.started <= now:
        parser.error("started must be a non-negative monotonic timestamp no later than now")
    root = Path(os.environ.get("RESULTS_DIR", ".DerivedData/TestResults"))
    root.mkdir(parents=True, exist_ok=True)
    entry = {"phase": args.phase, "scope": args.scope, "seconds": round((now - args.started) / 1e9, 3),
             "session_id": os.environ.get("TRINKET_DIAGNOSTICS_SESSION_ID", "")}
    entry['recorded_at'] = datetime.now(timezone.utc).isoformat()
    update_timing(root / 'phase-timing.jsonl', entry=entry, maximum=200)


if __name__ == "__main__":
    main()
