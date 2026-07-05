#!/usr/bin/env bash
# Wrapper for App Store / TestFlight release note generation.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$ROOT/Scripts/release-notes-user.py" "$@"
