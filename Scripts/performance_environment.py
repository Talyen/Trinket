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


def command(*args: str, raw: bool = False) -> str | bytes:
    try:
        output = subprocess.check_output(args, stderr=subprocess.DEVNULL, timeout=120)
        return output if raw else output.decode().strip()
    except (OSError, subprocess.SubprocessError) as error:
        # Provenance matters here: name the failed command so "unknown"
        # fields can be told apart from genuinely empty ones.
        print(f"performance_environment.py: {' '.join(args)} failed ({error}); recording unknown", file=sys.stderr)
        return b"unknown" if raw else "unknown"


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: performance_environment.py <output.json> <repetitions>")
    try:
        repetitions = int(sys.argv[2])
    except ValueError:
        raise SystemExit("repetitions must be an integer") from None
    output = Path(sys.argv[1])
    # --porcelain is the stable spelling of --short: one status run feeds both.
    git_status = command("git", "status", "--porcelain")
    untracked = [Path(os.fsdecode(name)) for name in
                 command("git", "ls-files", "-z", "--others", "--exclude-standard", raw=True).split(b"\0") if name]
    payload = {
        "capturedAt": datetime.now(timezone.utc).isoformat(),
        "host": platform.platform(),
        "xcode": command("xcodebuild", "-version"),
        "gitCommit": command("git", "rev-parse", "HEAD"),
        "gitDirty": bool(git_status),
        "gitStatus": git_status,
        "trackedDiffSHA256": hashlib.sha256(command("git", "diff", "--binary", "HEAD", raw=True)).hexdigest(),
        "untrackedSourceSHA256": {
            str(path): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in untracked if path.is_file() and path.suffix in {".swift", ".py", ".sh", ".json", ".xctestplan"}
        },
        "configuration": "Debug with SWIFT_OPTIMIZATION_LEVEL=-O",
        "quickSamplerPreparation": os.environ.get("TRINKET_PERFORMANCE_QUICK") == "1",
        "repetitionsPerScenario": repetitions,
        "suiteWallTimeoutSeconds": int(os.environ.get("TRINKET_XCODE_WALL_TIMEOUT_SECONDS", "1200")),
    }
    output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
