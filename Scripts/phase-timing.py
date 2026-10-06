#!/usr/bin/env python3
"""Append bounded preparation timings without parsing large Xcode transcripts."""
import os
from pathlib import Path
import sys
import time
from datetime import datetime, timezone
from internal.output_retention import update_timing

if sys.argv[1] == "begin":
    print(time.monotonic_ns())
else:
    phase, started, scope = sys.argv[2:5]
    root = Path(os.environ.get("RESULTS_DIR", ".DerivedData/TestResults"))
    root.mkdir(parents=True, exist_ok=True)
    entry = {"phase": phase, "scope": scope, "seconds": round(max(0, (time.monotonic_ns() - int(started)) / 1e9), 3),
             "session_id": os.environ.get("TRINKET_DIAGNOSTICS_SESSION_ID", "")}
    entry['recorded_at'] = datetime.now(timezone.utc).isoformat()
    update_timing(root / 'phase-timing.jsonl', entry=entry, maximum=200)
