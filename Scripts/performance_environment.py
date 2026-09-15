#!/usr/bin/env python3
"""Capture the host facts that accompany a performance run."""

from __future__ import annotations

import hashlib
import json
import os
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
        "gitStatus": command("git", "status", "--short"),
        "trackedDiffSHA256": hashlib.sha256(command("git", "diff", "HEAD").encode()).hexdigest(),
        "untrackedSourceSHA256": {
            name: hashlib.sha256(Path(name).read_bytes()).hexdigest()
            for name in command("git", "ls-files", "--others", "--exclude-standard").splitlines()
            if Path(name).is_file() and Path(name).suffix in {".swift", ".py", ".sh", ".json", ".xctestplan"}
        },
        "configuration": "Debug with SWIFT_OPTIMIZATION_LEVEL=-O",
        "quickSamplerPreparation": os.environ.get("TRINKET_PERFORMANCE_QUICK") == "1",
        "repetitionsPerScenario": repetitions,
        "suiteWallTimeoutSeconds": int(os.environ.get("TRINKET_XCODE_WALL_TIMEOUT_SECONDS", "1200")),
    }
    output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
