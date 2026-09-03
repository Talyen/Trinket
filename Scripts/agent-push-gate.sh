#!/usr/bin/env bash
# Commit-completeness gate for agents after commit and before push.
# Regenerates only when classification says content, project, or assets
# changed, then asserts generated output vs HEAD.
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=lib/tools.sh
source Scripts/lib/tools.sh

# shellcheck source=Scripts/change-classification.sh
source Scripts/change-classification.sh

PATH_MODE="working-tree"
declare -a requested_paths=()

usage() {
  cat <<'EOF'
Usage: ./Scripts/agent-push-gate.sh [--paths <file> ...]

Internal pre-push component: ensures generated catalogs/assets/project.pbxproj
match what CI will regenerate when the commit scope can affect them:
  1. ./Scripts/ensure-ci-tools.sh (pinned SwiftFormat/SwiftLint/XcodeGen)
  2. ./Scripts/generate.sh [--assets] --force-xcodegen (skipped when classification
     reports no content, project, or asset generation)
  3. ./Scripts/assert-generated-output.sh [--assets]

Without --paths, unions working-tree paths with local commits not present on a
remote (falling back to the latest commit). With --paths, only those paths drive
whether --assets is included.

Invoked automatically by the pre-push hook; not a manual post-commit step.
The user-facing workflow is focused iteration → path-scoped handoff → commit → push.

Env:
  SKIP_TRINKET_PUSH_GATE=1   Skip (for emergencies only)
  FORCE_ASSET_REENCODE=1     Force binary re-encode during generate --assets
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help | -h)
      usage
      exit 0
      ;;
    --paths)
      PATH_MODE="explicit"
      shift
      if [[ $# -eq 0 ]]; then
        echo "--paths requires at least one repository-relative path" >&2
        exit 1
      fi
      requested_paths=("$@")
      break
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ "${SKIP_TRINKET_PUSH_GATE:-}" == "1" ]]; then
  echo "Skipping agent push gate (SKIP_TRINKET_PUSH_GATE=1)."
  exit 0
fi

echo "=== Agent push gate: pinned tools ==="
trinket_require_pinned_tools

trinket_collect_committed_paths() {
  local path
  local remote_refs

  TRINKET_CHANGED_PATHS=()
  remote_refs="$(git for-each-ref --format='%(refname)' refs/remotes)"
  if [[ -n "$remote_refs" ]]; then
    while IFS= read -r path; do
      [[ -n "$path" ]] && TRINKET_CHANGED_PATHS+=("$path")
    done < <(
      git log -m --format= --name-only --diff-filter=ACMRD HEAD --not --remotes |
        sed '/^$/d' |
        sort -u
    )
  fi

  if [[ ${#TRINKET_CHANGED_PATHS[@]} -eq 0 ]]; then
    while IFS= read -r path; do
      [[ -n "$path" ]] && TRINKET_CHANGED_PATHS+=("$path")
    done < <(
      git diff-tree --root --no-commit-id --name-only -m -r --diff-filter=ACMRD HEAD |
        sort -u
    )
  fi
}

trinket_collect_paths "$PATH_MODE" "${requested_paths[@]-}"
if [[ "$PATH_MODE" == "working-tree" ]]; then
  working_paths=("${TRINKET_CHANGED_PATHS[@]-}")
  trinket_collect_committed_paths
  committed_paths=("${TRINKET_CHANGED_PATHS[@]-}")
  TRINKET_CHANGED_PATHS=()
  for path in "${working_paths[@]}" "${committed_paths[@]}"; do
    [[ -n "$path" ]] || continue
    trinket_add_unique TRINKET_CHANGED_PATHS "$path"
  done
fi

report_change_budget() {
  if [[ "$PATH_MODE" == "explicit" ]]; then
    ./Scripts/change-budget.sh --paths "${TRINKET_CHANGED_PATHS[@]}"
  else
    ./Scripts/change-budget.sh
  fi
}

if [[ "$PATH_MODE" == "working-tree" ]]; then
  echo "Commit scope: ${#TRINKET_CHANGED_PATHS[@]} path(s) selected for generation routing."
fi
if [[ ${#TRINKET_CHANGED_PATHS[@]} -gt 0 ]]; then
  trinket_classify_paths
else
  trinket_reset_classification
fi

INCLUDE_ASSETS=false
if [[ "$TRINKET_NEEDS_ASSET_GENERATION" == true ]]; then
  INCLUDE_ASSETS=true
fi

NEEDS_GENERATE=false
if [[ "$TRINKET_NEEDS_CONTENT_GENERATION" == true \
   || "$TRINKET_NEEDS_PROJECT_GENERATION" == true \
   || "$TRINKET_NEEDS_ASSET_GENERATION" == true ]]; then
  NEEDS_GENERATE=true
fi

if [[ "$NEEDS_GENERATE" != true ]]; then
  echo "=== Agent push gate: skip generate (no content, project, or asset inputs) ==="
  report_change_budget
  echo "=== Agent push gate passed ==="
  echo "Note: push-gate is generate/assert completeness only — not style or compile."
  echo "Pre-CI source checks: ./Scripts/handoff.sh --isolate --paths …"
  exit 0
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "=== Agent push gate: generate (XcodeGen unavailable; content only) ==="
  if [[ "$INCLUDE_ASSETS" == true ]]; then
    ./Scripts/generate.sh --assets --skip-xcodegen
  else
    ./Scripts/generate.sh --skip-xcodegen
  fi
  echo "=== Agent push gate: assert content catalogs ==="
  # shellcheck source=assert-generated-output.sh
  source Scripts/assert-generated-output.sh
  # Omit pbxproj: XcodeGen is unavailable, so project assert is deferred to CI.
  trinket_set_generated_tracked_paths "$INCLUDE_ASSETS" false
  if trinket_assert_committed_output; then
    echo "Content catalogs match manifests (pbxproj assert deferred to CI/XcodeGen)."
  else
    exit 1
  fi
  report_change_budget
  echo "=== Agent push gate passed ==="
  echo "Note: push-gate is generate/assert completeness only — not style or compile."
  echo "Pre-CI source checks: ./Scripts/handoff.sh --isolate --paths …"
  exit 0
fi

echo "=== Agent push gate: generate (pinned XcodeGen, force rewrite) ==="
if [[ "$INCLUDE_ASSETS" == true ]]; then
  ./Scripts/generate.sh --assets --force-xcodegen
  echo "=== Agent push gate: assert generated output (including assets) ==="
  ./Scripts/assert-generated-output.sh --assets
else
  ./Scripts/generate.sh --force-xcodegen
  echo "=== Agent push gate: assert generated output ==="
  ./Scripts/assert-generated-output.sh
fi

report_change_budget
echo "=== Agent push gate passed ==="
echo "Note: push-gate is generate/assert completeness only — not style or compile."
echo "Pre-CI source checks: ./Scripts/handoff.sh --isolate --paths …"
