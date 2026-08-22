#!/usr/bin/env bash
# Smoke-class routing constants for change-classification.sh.
#
# Scripts/config/smoke-classes.txt is the single registry (one KEY=Class line
# per smoke suite). This file derives the TRINKET_SMOKE_CLASS_* constants from
# it so the shell constants cannot drift from the registry that check-docs.py
# validates against Smoke.xctestplan.

_smokey_registry_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../config/smoke-classes.txt"
if [[ ! -r "${_smokey_registry_path}" ]]; then
  echo "smoke-class registry missing: ${_smokey_registry_path}" >&2
  (return 1 2>/dev/null) && return 1 || exit 1
fi
while IFS='=' read -r _smokey_key _smokey_value; do
  _smokey_key="${_smokey_key%$'\r'}"
  [[ -z "${_smokey_key}" || "${_smokey_key}" == \#* ]] && continue
  if [[ -z "${_smokey_value%$'\r'}" ]]; then
    echo "Malformed smoke-class registry line (expected KEY=Class): ${_smokey_key}" >&2
    (return 1 2>/dev/null) && return 1 || exit 1
  fi
  export "TRINKET_SMOKE_CLASS_${_smokey_key}=${_smokey_value%$'\r'}"
done < "$_smokey_registry_path"
unset _smokey_registry_path _smokey_key _smokey_value
