#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."
python3 Scripts/content_codegen.py validate
