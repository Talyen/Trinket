#!/usr/bin/env bash
# Thin git worktree helper for parallel agent checkouts.
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
WORKTREE_PARENT="$(cd "$ROOT/.." && pwd)"

usage() {
  cat <<'EOF'
Usage:
  ./Scripts/agent-worktree.sh create <slug>
  ./Scripts/agent-worktree.sh list
  ./Scripts/agent-worktree.sh remove <slug>

Creates a sibling checkout at ../Trinket-<slug> from the current HEAD, on the
same branch, so another agent can verify with --isolate without sharing a dirty
working tree. Does not create or switch git branches unless you ask separately.
EOF
}

slug_ok() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

worktree_path_for_slug() {
  printf '%s/Trinket-%s' "$WORKTREE_PARENT" "$1"
}

cmd="${1:-}"
case "$cmd" in
  create)
    slug="${2:-}"
    if [[ -z "$slug" ]]; then
      usage >&2
      exit 1
    fi
    if ! slug_ok "$slug"; then
      echo "Slug must be alphanumeric (plus ._-), got: $slug" >&2
      exit 1
    fi
    target="$(worktree_path_for_slug "$slug")"
    if [[ -e "$target" ]]; then
      echo "Worktree path already exists: $target" >&2
      exit 1
    fi
    git worktree add --detach "$target" HEAD
    cat <<EOF
Created worktree: $target

Checked out detached at the current HEAD (same commit as this tree; no new branch).
Next:
  cd "$target"
  ./Scripts/verify-changed.sh --isolate --paths <file...>

Use a unique TRINKET_RUN_ID / --isolate in each worktree so DerivedData and
simulators do not collide with peers on this Mac.
EOF
    ;;
  list)
    git worktree list
    ;;
  remove)
    slug="${2:-}"
    if [[ -z "$slug" ]]; then
      usage >&2
      exit 1
    fi
    if ! slug_ok "$slug"; then
      echo "Slug must be alphanumeric (plus ._-), got: $slug" >&2
      exit 1
    fi
    target="$(worktree_path_for_slug "$slug")"
    if [[ ! -d "$target" ]]; then
      echo "No worktree at $target" >&2
      exit 1
    fi
    git worktree remove "$target"
    echo "Removed worktree: $target"
    ;;
  -h|--help|help|"")
    usage
    exit 0
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    usage >&2
    exit 1
    ;;
esac
