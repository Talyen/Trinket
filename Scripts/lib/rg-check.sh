#!/usr/bin/env bash
# Shared harness for the ripgrep-based gate scripts.
#
# Sourced by check-agent-invariants.sh, check-exclusivity-footguns.sh,
# check-comment-ban.sh, and check-module-boundaries.sh. On source it moves
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
#
# bash 3.2-safe: indexed arrays only, no associative arrays, no mapfile.

_trinket_rg_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$_trinket_rg_root" || exit 1
unset _trinket_rg_root

violations=()

TRINKET_RG_BULLET="${TRINKET_RG_BULLET:-  - }"

trinket_rg_violation() {
  violations+=("$1")
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
