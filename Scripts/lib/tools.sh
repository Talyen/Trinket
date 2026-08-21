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
