#!/usr/bin/env bash
# Thin wrapper: app-compile is build-for-testing.sh --app-only.
# xcode-runner.sh injects COMPILER_INDEX_STORE_ENABLE=NO plus simulator
# CODE_SIGNING_* flags, so this wrapper carries no explicit flags.
set -euo pipefail

cd "$(dirname "$0")/.."
exec ./Scripts/build-for-testing.sh --app-only "$@"
