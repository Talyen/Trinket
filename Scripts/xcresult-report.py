#!/usr/bin/env python3
"""Read one completed invocation report, reusing its validated export when available."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from internal.diagnostics.xcresult_diagnostics import run_xcresulttool


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("kind", choices=("summary", "tests"))
    args = parser.parse_args()
    payload, error = run_xcresulttool(args.bundle, ["get", "test-results", args.kind], timeout_seconds=60)
    if error:
        raise SystemExit(error)
    print(json.dumps(payload, separators=(",", ":")))


if __name__ == "__main__":
    main()
