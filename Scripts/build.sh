#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."
xcodegen generate
xcodebuild build \
  -project Trinket.xcodeproj \
  -scheme Trinket \
   -destination 'platform=iOS Simulator,name=iPhone 17 Pro'


