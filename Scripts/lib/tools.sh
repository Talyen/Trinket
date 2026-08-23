#!/usr/bin/env bash

trinket_prepend_pinned_tools() {
  local root="${1:-$PWD}"
  if [[ -d "$root/.tools" ]]; then
    export PATH="$root/.tools:$PATH"
  fi
}

# Install pinned tools, put them on PATH, and require them for subsequent calls.
trinket_require_pinned_tools() {
  local root="${1:-$PWD}"
  "$root/Scripts/ensure-ci-tools.sh"
  trinket_prepend_pinned_tools "$root"
  export TRINKET_REQUIRE_PINNED_TOOLS=1
}

# Require <binary> on PATH at the pinned version, exiting with install guidance
# otherwise. Any arguments after the expected version are passed to the tool's
# version command (e.g. "version" for swiftlint, "--version" for swiftformat).
trinket_require_pinned_version() {
  local binary="$1" expected="$2"
  shift 2
  if ! command -v "$binary" &>/dev/null; then
    echo "$binary is not installed."
    echo "Install the pinned version via: ./Scripts/ensure-ci-tools.sh"
    echo "Or: brew install $binary (must be $expected)"
    exit 1
  fi

  local installed
  installed="$("$binary" "$@" 2>/dev/null || true)"
  if [[ "$installed" != "$expected" ]]; then
    echo "$binary version mismatch: expected $expected, found $installed"
    echo "Install the pinned version via: ./Scripts/ensure-ci-tools.sh"
    exit 1
  fi
}
