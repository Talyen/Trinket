#!/usr/bin/env bash
# Derive smoke routing constants from the shared UI-test registry. Full schema
# validation and generation are owned by check-testplan-sync.py.
_smokey_registry="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/ui-tests.tsv"
if [[ ! -r "$_smokey_registry" ]]; then
  echo "UI-test registry missing: $_smokey_registry" >&2
  return 1
fi
while IFS='|' read -r _smokey_suite _smokey_key _smokey_class _smokey_rest; do
  [[ -z "$_smokey_suite" || "$_smokey_suite" == \#* ]] && continue
  [[ "$_smokey_suite" == FullUI ]] && continue
  if [[ "$_smokey_suite" != Smoke || ! "$_smokey_key" =~ ^[A-Z][A-Z0-9_]*$ || ! "$_smokey_class" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "Malformed UI-test registry row: $_smokey_suite" >&2
    return 1
  fi
  export "TRINKET_SMOKE_CLASS_${_smokey_key}=$_smokey_class"
done < "$_smokey_registry"
unset _smokey_registry _smokey_suite _smokey_key _smokey_class _smokey_rest
