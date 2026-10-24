#!/usr/bin/env bash
# CI validates prepared outputs without checking out source masters.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  echo "Usage: $0"
  echo "Validate committed prepared assets without source masters."
  exit 0
fi
./Scripts/prepare-assets.sh --check --outputs-only
python3 Scripts/check-unused-assets.py
