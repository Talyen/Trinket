#!/usr/bin/env bash
# Orchestrate version bump, changelog generation, and release tagging.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION=""
SKIP_TESTS=false
DRY_RUN=false
NO_TAG=false
SINCE_TAG=""

usage() {
  cat <<'EOF'
Usage: ./Scripts/release.sh [options]

Creates a release: bumps version in project.yml, regenerates CHANGELOG.md and
ReleaseNotes/en-US.txt, commits, and tags vX.Y.Z.

Options:
  --version X.Y.Z    Explicit marketing version (default: auto-bump from commits)
  --since-tag TAG    Generate notes since this tag (default: latest v* tag)
  --skip-tests       Skip ./Scripts/test-deploy.sh (not recommended)
  --dry-run          Print actions without writing, committing, or tagging
  --no-tag           Commit release assets but do not create a git tag
  -h, --help         Show this help

Examples:
  ./Scripts/release.sh                    # patch/minor bump from commits since last tag
  ./Scripts/release.sh --version 1.0.0    # explicit semver
  ./Scripts/release.sh --dry-run          # preview the release
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION="${2:?--version requires X.Y.Z}"
      shift 2
      ;;
    --since-tag)
      SINCE_TAG="${2:?--since-tag requires a tag}"
      shift 2
      ;;
    --skip-tests) SKIP_TESTS=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --no-tag) NO_TAG=true; shift ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

read_project_version() {
  MARKETING_VERSION="$(grep 'MARKETING_VERSION:' project.yml | head -1 | sed -E 's/.*"([0-9.]+)".*/\1/')"
  BUILD_NUMBER="$(grep 'CURRENT_PROJECT_VERSION:' project.yml | head -1 | sed -E 's/.*"([0-9]+)".*/\1/')"
}

write_project_version() {
  local marketing="$1"
  local build="$2"
  perl -pi '' -e "s/MARKETING_VERSION: \".*\"/MARKETING_VERSION: \"${marketing}\"/" project.yml
  perl -pi '' -e "s/CURRENT_PROJECT_VERSION: \".*\"/CURRENT_PROJECT_VERSION: \"${build}\"/" project.yml
}

latest_tag() {
  git tag -l 'v[0-9]*' --sort=-v:refname | head -1
}

suggest_version() {
  local current="$1"
  local since="${2:-}"

  if [[ -n "$since" ]] && ./Scripts/release-notes.sh bump 2>/dev/null | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    ./Scripts/release-notes.sh bump
    return
  fi

  local major minor patch
  IFS='.' read -r major minor patch <<<"$current"

  local range="${since:+$since..}HEAD"
  local log
  log="$(git log $range --pretty=%s --no-merges 2>/dev/null || true)"

  if grep -qiE 'BREAKING CHANGE|^[^ ]+!:' <<<"$log"; then
    echo "$((major + 1)).0.0"
  elif grep -qE '^(feat|content)(\(|:)|^(Add|Introduce|Implement|Complete|Enable|Extend)' <<<"$log"; then
    echo "${major}.$((minor + 1)).0"
  else
    echo "${major}.${minor}.$((patch + 1))"
  fi
}

read_project_version

if [[ -z "${SINCE_TAG}" ]]; then
  SINCE_TAG="$(latest_tag || true)"
fi

if [[ -z "$VERSION" ]]; then
  if [[ -z "$SINCE_TAG" ]]; then
    VERSION="0.1.0"
  else
    VERSION="$(suggest_version "$MARKETING_VERSION" "$SINCE_TAG")"
  fi
fi

TAG="v${VERSION}"
NEXT_BUILD=$((BUILD_NUMBER + 1))

if [[ -n "$SINCE_TAG" ]]; then
  COMMIT_COUNT="$(git log "${SINCE_TAG}..HEAD" --oneline --no-merges | wc -l | tr -d ' ')"
else
  COMMIT_COUNT="$(git rev-list --count HEAD)"
fi

if [[ "$COMMIT_COUNT" == "0" && "$DRY_RUN" == "false" ]]; then
  echo "No commits since ${SINCE_TAG:-the beginning of history}; nothing to release." >&2
  exit 1
fi

echo "=== Trinket release ${TAG} (build ${NEXT_BUILD}) ==="
echo "Since: ${SINCE_TAG:-<initial>}"
echo "Commits: ${COMMIT_COUNT}"

if [[ "$SKIP_TESTS" == "false" && "$DRY_RUN" == "false" ]]; then
  echo ""
  echo "=== Running deploy gate ==="
  ./Scripts/test-deploy.sh
elif [[ "$SKIP_TESTS" == "false" ]]; then
  echo "(dry-run: skipping test-deploy.sh)"
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo ""
  echo "=== Dry run preview ==="
  echo "Would set MARKETING_VERSION=${VERSION}, CURRENT_PROJECT_VERSION=${NEXT_BUILD}"
  ./Scripts/release-notes-user.sh --version "$VERSION" ${SINCE_TAG:+--since-tag "$SINCE_TAG"} --dry-run || true
  exit 0
fi

echo ""
echo "=== Updating project.yml ==="
write_project_version "$VERSION" "$NEXT_BUILD"
./Scripts/generate.sh

echo ""
echo "=== Generating CHANGELOG.md ==="
./Scripts/release-notes.sh validate
./Scripts/release-notes.sh prepend "$TAG"

echo ""
echo "=== Generating App Store release notes ==="
./Scripts/release-notes-user.sh --version "$VERSION" ${SINCE_TAG:+--since-tag "$SINCE_TAG"}

echo ""
echo "=== Committing release ==="
git add project.yml CHANGELOG.md ReleaseNotes/ fastlane/metadata/
git commit -m "chore(release): ${TAG} (build ${NEXT_BUILD})

- Bump MARKETING_VERSION to ${VERSION}
- Regenerate CHANGELOG.md and App Store release notes"

if [[ "$NO_TAG" == "false" ]]; then
  git tag -a "$TAG" -m "Release ${TAG} (build ${NEXT_BUILD})"
  echo ""
  echo "Tagged ${TAG}. Push with: git push origin main --tags"
else
  echo ""
  echo "Release commit created (--no-tag; no git tag added)."
fi

echo ""
echo "=== Release ${TAG} complete ==="
