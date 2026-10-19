#!/usr/bin/env python3
"""Validate and preserve a release's archive, dSYMs, and upload symbol payload."""

from internal.build_symbols import main

if __name__ == "__main__":
    raise SystemExit(main())
