#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

HOOK_DIR=".githooks"
HOOK_PATH="$HOOK_DIR/pre-push"

mkdir -p "$HOOK_DIR"

cat > "$HOOK_PATH" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

if ! command -v swiftformat >/dev/null 2>&1; then
  echo "[pre-push] swiftformat not found on PATH (.tools); skipping auto-format." >&2
  exit 0
fi

echo "[pre-push] running swiftformat (apply) on staged Swift files..."
STAGED_SWIFT="$(git diff --cached --name-only --diff-filter=ACMRT | grep -E '\.swift$' || true)"
if [[ -z "$STAGED_SWIFT" ]]; then
  exit 0
fi

# Apply formatting in place; do not block push on lint — CI gates style.
# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh
trinket_prepend_pinned_tools 2>/dev/null || true

echo "$STAGED_SWIFT" | xargs swiftformat 2>&1 | head -n 40 || true

STAGED_CHANGED="$(git diff --name-only | grep -E '\.swift$' || true)"
if [[ -z "$STAGED_CHANGED" ]]; then
  exit 0
fi
TO_RESTORE="$(printf '%s\n' "$STAGED_SWIFT" | grep -Fx -f <(printf '%s\n' "$STAGED_CHANGED") || true)"
if [[ -z "$TO_RESTORE" ]]; then
  exit 0
fi
echo "[pre-push] swiftformat touched files; re-staging." >&2
printf '%s\n' "$TO_RESTORE" | xargs git add 2>/dev/null || true
HOOK

chmod +x "$HOOK_PATH"
git config core.hooksPath "$HOOK_DIR"
echo "Installed opt-in pre-push hook at $HOOK_PATH (core.hooksPath=$HOOK_DIR)"
echo "It runs swiftformat (apply) on staged Swift files and re-stages fixes. Lint/style remains a CI gate."
echo "To remove: git config --unset core.hooksPath && rm -rf $HOOK_DIR"
