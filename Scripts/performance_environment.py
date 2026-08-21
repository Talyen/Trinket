#!/usr/bin/env python3
"""Capture the host facts that accompany a performance run."""

from __future__ import annotations

import json
import platform
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


def command(*args: str) -> str:
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL).strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: performance_environment.py <output.json> <repetitions>")
    try:
        repetitions = int(sys.argv[2])
    except ValueError:
        raise SystemExit("repetitions must be an integer") from None
    output = Path(sys.argv[1])
    payload = {
        "capturedAt": datetime.now(timezone.utc).isoformat(),
        "host": platform.platform(),
        "xcode": command("xcodebuild", "-version"),
        "gitCommit": command("git", "rev-parse", "HEAD"),
        "gitDirty": bool(command("git", "status", "--porcelain")),
        "repetitionsPerScenario": repetitions,
    }
    output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
