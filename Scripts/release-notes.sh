#!/usr/bin/env bash
# Generate CHANGELOG.md entries from git history using git-cliff.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CLIFF=(./Scripts/ensure-git-cliff.sh --offline)

usage() {
  cat <<'EOF'
Usage: ./Scripts/release-notes.sh <command> [options]

Commands:
  unreleased              Print unreleased changelog section to stdout
  prepend <tag>           Prepend a versioned section to CHANGELOG.md (e.g. v0.2.0)
  github-body <tag>       Print GitHub Release body for a tag
  bump                    Print suggested next semver (requires at least one tag)
  validate                Verify cliff.toml parses current history

Options:
  --config <path>         git-cliff config (default: cliff.toml)
EOF
}

CONFIG="cliff.toml"
COMMAND=""
TAG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    unreleased | prepend | github-body | bump | validate)
      COMMAND="$1"
      shift
      ;;
    --config)
      CONFIG="${2:?--config requires a path}"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    v[0-9]*)
      TAG="$1"
      shift
      ;;
    *)
      case "$COMMAND" in
        prepend | github-body)
          if [[ -z "$TAG" ]]; then
            TAG="$1"
            shift
          else
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
          fi
          ;;
        *)
          echo "Unknown argument: $1" >&2
          usage >&2
          exit 1
          ;;
      esac
      ;;
  esac
done

if [[ -z "$COMMAND" ]]; then
  usage >&2
  exit 1
fi

case "$COMMAND" in
  unreleased)
    "${CLIFF[@]}" --config "$CONFIG" --unreleased
    ;;
  prepend)
    [[ -n "$TAG" ]] || { echo "prepend requires a tag (e.g. v0.2.0)" >&2; exit 1; }
    "${CLIFF[@]}" --config "$CONFIG" --tag "$TAG" --prepend CHANGELOG.md
    python3 "$ROOT/Scripts/release-notes-user.py" --strip-unreleased CHANGELOG.md
    ;;
  github-body)
    [[ -n "$TAG" ]] || { echo "github-body requires a tag" >&2; exit 1; }
    "${CLIFF[@]}" --config "$CONFIG" --tag "$TAG" --strip header
    ;;
  bump)
    if [[ -z "$(git tag -l 'v[0-9]*')" ]]; then
      echo "0.1.0"
      exit 0
    fi
    "${CLIFF[@]}" --config "$CONFIG" --unreleased --bumped-version 2>/dev/null | tail -1
    ;;
  validate)
    "${CLIFF[@]}" --config "$CONFIG" --unreleased >/dev/null
    echo "cliff.toml OK"
    ;;
esac
