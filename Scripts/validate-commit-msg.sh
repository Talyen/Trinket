#!/usr/bin/env bash
# Validate commit message format (advisory; local commit-msg hook only).
set -euo pipefail

MSG_FILE="${1:-}"
if [[ -z "$MSG_FILE" || ! -f "$MSG_FILE" ]]; then
  echo "Usage: $0 <commit-msg-file>" >&2
  exit 1
fi

MSG="$(cat "$MSG_FILE")"
SUBJECT="$(printf '%s\n' "$MSG" | sed -n '1p')"

if [[ "$SUBJECT" =~ ^Merge\  ]]; then
  exit 0
fi

if [[ "$SUBJECT" =~ ^Revert\  ]]; then
  exit 0
fi

if [[ "$SUBJECT" =~ ^chore\(release\): ]]; then
  exit 0
fi

WARN=0

# Accept conventional commits or imperative agent-style subjects.
if [[ ! "$SUBJECT" =~ ^(feat|fix|perf|refactor|content|style|test|ci|chore|docs|build)(\([a-z0-9._-]+\))?!?:\ .+ ]]; then
  if [[ ! "$SUBJECT" =~ ^[A-Z].{4,} ]]; then
    echo "commit-msg: subject should start with type(scope): or an imperative capitalized phrase" >&2
    WARN=1
  fi
fi

if ((${#SUBJECT} > 72)); then
  echo "commit-msg: subject exceeds 72 characters (${#SUBJECT})" >&2
  WARN=1
fi

if ! printf '%s\n' "$MSG" | sed -n '2,$p' | grep -qE '^$|^[-*]|^Breaking:|^Co-authored-by:'; then
  echo "commit-msg: consider a blank line after the subject with bullet details" >&2
  WARN=1
fi

if [[ "$WARN" -ne 0 ]]; then
  echo "commit-msg: advisory warnings only (commit allowed). See Docs/Platform/Release.md." >&2
fi

exit 0
