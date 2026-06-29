#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v swiftlint &>/dev/null; then
  echo "SwiftLint is not installed. Install via: brew install swiftlint"
  exit 0
fi

swiftlint lint --quiet "$@"
