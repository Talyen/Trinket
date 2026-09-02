#!/usr/bin/env bash
# Fail on exclusivity footguns: passing inout of a stored property on self while
# other self state is also accessed/mutated in the same call tree (classic Swift
# overlapping-access compile break).
#
# Catches:
#   1. Explicit `&self.property`
#   2. `into: &property` where `property` was not introduced as a nearby local `var`
#      (the PlayerRosterState unlock footgun)
#
# Escape hatch: nearby `ExclusivityCheck: allow` with a concrete reason.
set -euo pipefail

# shellcheck source=Scripts/lib/rg-check.sh
source "$(dirname "$0")/lib/rg-check.sh"

# shellcheck source=swift-source-dirs.env
source ./Scripts/swift-source-dirs.env
SOURCE_DIRS=("${SWIFT_SOURCE_DIRS[@]}")

TRINKET_RG_BULLET="  "

is_allowed() {
  local file="$1"
  local line_number="$2"

  local start=$((line_number > 4 ? line_number - 4 : 1))
  local end="$line_number"
  if sed -n "${start},${end}p" "$file" \
    | grep -Eq '^[[:space:]]*//[[:space:]]*ExclusivityCheck:[[:space:]]*allow[[:space:]]*-[[:space:]]*[[:graph:]]'; then
    return 0
  fi
  return 1
}

# True when IDENT was introduced as a local `var` or as an `inout` parameter
# in the preceding window (safe to pass by inout without overlapping self).
has_safe_inout_target() {
  local file="$1"
  local line_number="$2"
  local ident="$3"
  # Limit the declaration search to the current function. The previous fixed
  # window could mistake a similarly named local in a preceding function for
  # the target and suppress a real stored-property overlap.
  local function_start
  function_start="$(awk -v n="$line_number" 'NR <= n && $0 ~ /(^|[[:space:]])func[[:space:]]/ { last = NR } END { print last + 0 }' "$file")"
  local start
  if [[ "$function_start" -gt 0 ]]; then
    start="$function_start"
  else
    start=$((line_number > 60 ? line_number - 60 : 1))
  fi
  local end=$((line_number - 1))
  if (( end < start )); then
    return 1
  fi
  local window
  window="$(sed -n "${start},${end}p" "$file")"
  if printf '%s\n' "$window" | grep -Eq "[[:space:]]var[[:space:]]+${ident}([[:space:]]*:[[:space:]]*[^=]+)?[[:space:]]*="; then
    return 0
  fi
  if printf '%s\n' "$window" | grep -Eq "(into[[:space:]]+)?${ident}:[[:space:]]*inout[[:space:]]"; then
    return 0
  fi
  return 1
}

while IFS=: read -r file line_number content; do
  [[ -z "${file:-}" ]] && continue
  if is_allowed "$file" "$line_number"; then
    continue
  fi
  trinket_rg_violation "${file}:${line_number}: ${content}"
done < <(
  rg -n --glob '*.swift' --glob '!**/Generated/**' '&self\.' "${SOURCE_DIRS[@]}" 2>/dev/null || true
)

while IFS=: read -r file line_number content; do
  [[ -z "${file:-}" ]] && continue
  if is_allowed "$file" "$line_number"; then
    continue
  fi
  ident="$(printf '%s\n' "$content" | sed -n 's/.*into:[[:space:]]*&\([A-Za-z_][A-Za-z0-9_]*\).*/\1/p')"
  [[ -z "$ident" ]] && continue
  if has_safe_inout_target "$file" "$line_number" "$ident"; then
    continue
  fi
  trinket_rg_violation "${file}:${line_number}: ${content}"
done < <(
  rg -n --glob '*.swift' --glob '!**/Generated/**' 'into:[[:space:]]*&[A-Za-z_]' "${SOURCE_DIRS[@]}" 2>/dev/null || true
)

trinket_rg_report "Exclusivity footgun check found inout of a likely stored property:" "Exclusivity footgun check passed." "" \
  "Copy the property to a local var, pass &local, then write back — see PlayerRosterState.unlockHero." \
  "Escape hatch: // ExclusivityCheck: allow - <reason> on a nearby line."
