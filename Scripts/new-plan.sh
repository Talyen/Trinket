#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

name="${1:-}"
if [[ -z "$name" ]]; then
  echo "Usage: ./Scripts/new-plan.sh <PlanName>" >&2
  exit 2
fi

safe_name="${name//[^A-Za-z0-9._-]/-}"
if [[ "$safe_name" != "$name" || -z "$safe_name" ]]; then
  echo "Plan name must contain only letters, numbers, dots, underscores, and hyphens" >&2
  exit 2
fi

path="Docs/Plans/${safe_name}.md"
if [[ -e "$path" ]]; then
  echo "Plan already exists: $path" >&2
  exit 1
fi

created="$(date -u +%F)"
expires="$(python3 - "$created" <<'PY'
from datetime import date, timedelta
import sys

print(date.fromisoformat(sys.argv[1]) + timedelta(days=14))
PY
)"

cat > "$path" <<EOF
---
type: execution-plan
status: active
created: $created
updated: $created
expires: $expires
---

# $safe_name

## Objective

Describe the user-visible outcome and the bounded implementation scope.

## Plan

- [ ] Record the baseline and relevant constraints.
- [ ] Implement the smallest complete change.
- [ ] Add or extend only consequential coverage.
- [ ] Run path-scoped verification.
- [ ] Mark the work complete, delete this file, and report verification.

## Notes

Keep durable policy in its canonical documentation owner. Delete this plan when the work is complete.
EOF

echo "Created $path"
