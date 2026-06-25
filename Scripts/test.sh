#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."
xcodegen generate
xcodebuild test \
  -project Trinket.xcodeproj \
  -scheme Trinket \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5'
