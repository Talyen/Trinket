#!/usr/bin/env bash

trinket_path_category() {
  local p="$1"
  if [[ "$p" =~ (^|/)(Generated/|\.generated\.swift$|^Trinket\.xcodeproj/|^.DerivedData/|^.tools/|^Raw\ Assets/) ]]; then
    printf 'generated'
    return
  fi
  if [[ "$p" =~ (^TrinketUITests/.*|.*/Tests/.*|^Scripts/Tests/.*|^Packages/TrinketTestSupport/.*|^Packages/TrinketPersistence/Sources/TrinketPersistenceTestSupport/.*|^Packages/TrinketTestSupport/.*) ]]; then
    if [[ "$p" == *.swift ]]; then
      printf 'support'
      return
    fi
    printf 'test'
    return
  fi
  if [[ "$p" =~ (^TrinketUITests/.*|.*/Tests/.*) ]]; then
    printf 'test'
    return
  fi
  if [[ "$p" == *.swift ]]; then
    printf 'production'
  else
    printf 'docs'
  fi
}

trinket_is_support_path() {
  [[ "$(trinket_path_category "$1")" == "support" ]]
}
