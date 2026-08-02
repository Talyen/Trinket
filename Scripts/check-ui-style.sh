#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Fast Python scanner (replaces the previous bash line-by-line pass).
# Optional args: Swift files or directories to scan (default: product UI trees).
exec python3 ./Scripts/check-ui-style.py "$@"
