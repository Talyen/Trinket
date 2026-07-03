#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."
echo "Note: prefer ./Scripts/generate.sh (runs validation, codegen, and XcodeGen)." >&2
python3 Scripts/content_codegen.py
