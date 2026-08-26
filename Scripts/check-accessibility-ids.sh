#!/usr/bin/env bash
# AccessibilityID uniqueness and UITest identifier literals.
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 ./Scripts/check-accessibility-ids.py "$@"
