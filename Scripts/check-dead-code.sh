#!/usr/bin/env bash
# Runs Periphery dead code and redundant public accessibility analysis.
set -euo pipefail

cd "$(dirname "$0")/.."

# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh
trinket_prepend_pinned_tools

OPTIONAL=false
for arg in "$@"; do
  case "$arg" in
    --optional|--allow-missing)
      OPTIONAL=true
      ;;
  esac
done

if ! command -v periphery >/dev/null 2>&1; then
  echo "Periphery not found on PATH." >&2
  echo "Install Periphery via brew (brew install periphery) or visit https://periphery.pro." >&2
  echo "Configuration is located at .periphery.yml." >&2
  if [[ "$OPTIONAL" == true ]]; then
    echo "Skipping periphery scan (--optional specified)." >&2
    exit 0
  fi
  exit 1
fi

echo "=== Running Periphery Dead Code Scan ==="
periphery scan "$@"
