#!/usr/bin/env bash

trinket_run_style_gate() {
  local -a style_paths=("$@")
  local style_status=0
  if (( ${#style_paths[@]} > 0 )); then
    echo "Running path-scoped style on ${#style_paths[@]} path(s)..."
    ./Scripts/format.sh --lint -- "${style_paths[@]}" || style_status=$?
    ./Scripts/lint.sh -- "${style_paths[@]}" || style_status=$?
    python3 ./Scripts/check-ui-style.py "${style_paths[@]}" || style_status=$?
  else
    ./Scripts/format.sh --lint || style_status=$?
    ./Scripts/lint.sh || style_status=$?
    python3 ./Scripts/check-ui-style.py || style_status=$?
  fi
  ./Scripts/check-api-bans.sh || style_status=$?
  ./Scripts/check-exclusivity-footguns.sh || style_status=$?
  ./Scripts/check-agent-invariants.sh || style_status=$?
  python3 ./Scripts/check-accessibility-ids.py || style_status=$?
  if (( ${#style_paths[@]} > 0 )); then
    ./Scripts/check-comment-ban.sh -- "${style_paths[@]}" || style_status=$?
  else
    ./Scripts/check-comment-ban.sh || style_status=$?
  fi
  if [[ "$style_status" -ne 0 ]]; then
    echo "Style gate failed (format / lint / UI style / platform API bans / exclusivity / agent invariants / accessibility IDs / comment ban)." >&2
    return "$style_status"
  fi
  echo "Style gate passed."
}
