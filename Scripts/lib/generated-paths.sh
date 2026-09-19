#!/usr/bin/env bash

# Single parser for Scripts/config/generated-paths.tsv — one home for the
# row shape previously restated in assert-generated-output.sh (tracked-path
# list) and change-classification.sh (generated-output routing).
# Safe to source twice. Prints normalized non-comment rows as kind|path;
# malformed rows (no `|`, empty kind/path) are skipped, and trailing slashes
# are stripped so prefix matching cannot drift between consumers.
[[ -n "${_TRINKET_GENERATED_PATHS_SH_LOADED:-}" ]] && return 0
_TRINKET_GENERATED_PATHS_SH_LOADED=1

trinket_generated_registry_rows() {
  local registry="$1" line kind path
  while IFS= read -r line; do
    case "$line" in ''|\#*) continue ;; esac
    case "$line" in *\|*) ;; *) continue ;; esac
    kind="${line%%|*}"
    path="${line#*|}"
    [[ -n "$kind" && -n "$path" ]] || continue
    printf '%s|%s\n' "$kind" "${path%/}"
  done < "$registry"
}
