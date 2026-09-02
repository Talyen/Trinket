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

Describe the user-visible outcome and initial implementation scope. Confirmed
encountered fixes may expand it under the root agent policy.

## Plan

- [ ] Record the baseline and relevant constraints.
- [ ] Implement the most pragmatic complete change — the cleanest architectural shape that fully satisfies the objective, not the narrowest diff.
- [ ] Record evidenced scope expansions and include their complete remedies and owners.
- [ ] Add or extend only consequential coverage.
- [ ] Run path-scoped verification for the union of requested and adopted changes.
- [ ] Record the outcome in \`Docs/Plans/Archived/README.md\`, delete this file, and report verification.

## Notes

Keep durable policy in its canonical documentation owner. When the work is complete, record the outcome in \`Docs/Plans/Archived/README.md\` and delete this plan; Git history retains the full text.
EOF

echo "Created $path"
