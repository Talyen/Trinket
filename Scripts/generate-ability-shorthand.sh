#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
echo "Note: generating the complete content catalog under the shared generation lock." >&2
exec ./Scripts/generate.sh --skip-xcodegen
