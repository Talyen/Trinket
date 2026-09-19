#!/usr/bin/env bash
# Shared harness for the ripgrep-based gate scripts.
#
# Sourced by check-agent-invariants.sh, check-exclusivity-footguns.sh,
# and check-module-boundaries.sh. On source it moves
# to the repository root and provides the violations convention plus the
# shared failure/OK reporter. Callers own every rule, pattern, and message;
# this file only owns the mechanics.
#
# Convention:
#   trinket_rg_violation "<file:line: message>"   append one violation
#   TRINKET_RG_BULLET="  - "                      violation line prefix
#   trinket_rg_report "<fail-header>" "<ok-message>" ["<title>" [footer...]]
#     prints the header plus one bullet per violation to stderr and one
#     ::error annotation per violation to stdout when GITHUB_ACTIONS=true
#     and a title was given, then exits 1; otherwise echoes the OK message.
#   trinket_rg_has_nearby_allow <file> <line> <marker>
#     true when a `// <marker>: allow - <reason>` comment appears on one of
#     the 4 lines ending at <line> (shared escape-hatch window).
#   trinket_rg_contains <pattern> <target>
#     true when the pattern is present in the target file (rg with grep
#     fallback); false when absent. Exits 2+ on search error.
#
# bash 3.2-safe: indexed arrays only, no associative arrays, no mapfile.

_trinket_rg_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$_trinket_rg_root" || exit 1
unset _trinket_rg_root

violations=()

TRINKET_RG_BULLET="${TRINKET_RG_BULLET:-  - }"

# Run in the caller, not process substitution, so a search error stops the gate.
# NOTE: ripgrep omits the file prefix when every input is an explicit file.
# Callers parsing file:line matches must pass --with-filename in that case.
trinket_rg_scan() {
  local status
  if TRINKET_RG_MATCHES="$(rg "$@")"; then
    return 0
  else
    status=$?
  fi
  [[ "$status" -eq 1 ]] && return 0
  echo "Policy search failed (rg exit $status)." >&2
  exit "$status"
}

trinket_rg_violation() {
  violations+=("$1")
}

# Shared nearby-allow window for `// <marker>: allow - <reason>` escape hatches.
trinket_rg_has_nearby_allow() {
  local _file="$1"
  local _line_number="$2"
  local _marker="$3"
  local _start=$((_line_number > 4 ? _line_number - 4 : 1))
  if sed -n "${_start},${_line_number}p" "$_file" \
    | grep -Eq "^[[:space:]]*//[[:space:]]*${_marker}:[[:space:]]*allow[[:space:]]*-[[:space:]]*[[:graph:]]"; then
    return 0
  fi
  return 1
}

# Shared presence probe for constant-enforcement gates.
trinket_rg_contains() {
  local _pattern="$1"
  local _target="$2"
  if command -v rg >/dev/null 2>&1; then
    rg -q --no-ignore -g '!*' "$_pattern" "$_target" 2>/dev/null
  else
    grep -Eq "$_pattern" "$_target"
  fi
}

_trinket_rg_trim() {
  local _text="$1"
  _text="${_text#"${_text%%[![:space:]]*}"}"
  _text="${_text%"${_text##*[![:space:]]}"}"
  printf '%s' "$_text"
}

trinket_rg_report() {
  local _header="$1"
  local _ok="$2"
  shift 2 || true
  local _title=""
  if (( $# >= 1 )); then
    _title="$1"
    shift || true
  fi
  if (( ${#violations[@]} == 0 )); then
    echo "$_ok"
    return 0
  fi
  echo "$_header" >&2
  local _entry
  for _entry in "${violations[@]}"; do
    echo "${TRINKET_RG_BULLET:-  - }${_entry}" >&2
    if [[ -n "$_title" && "${GITHUB_ACTIONS:-}" == "true" ]]; then
      local _file="$_entry"
      local _after=""
      local _line="1"
      local _msg="$_entry"
      if [[ "$_entry" == *:* ]]; then
        _file="${_entry%%:*}"
        _after="${_entry#*:}"
        if [[ "$_after" =~ ^[0-9]+: ]]; then
          _line="${_after%%:*}"
          _msg="${_after#*:}"
        elif [[ "$_after" =~ ^[0-9]+$ ]]; then
          _line="$_after"
          _msg=""
        else
          _line="1"
          _msg="$_after"
        fi
      fi
      _file="$(_trinket_rg_trim "$_file")"
      _line="$(_trinket_rg_trim "$_line")"
      _msg="$(_trinket_rg_trim "$_msg")"
      if [[ -z "$_line" ]]; then
        _line="1"
      fi
      echo "::error file=$_file,line=$_line,title=$_title::$_msg"
    fi
  done
  local _footer
  for _footer in "$@"; do
    echo "$_footer" >&2
  done
  exit 1
}
