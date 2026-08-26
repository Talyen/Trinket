#!/usr/bin/env bash
# Generated-output assert helpers. Executable as a gate; sourceable for the
# shared tracked-path list and committed-drift check (agent-push-gate fallback).

TRINKET_GENERATED_OUTPUT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

trinket_set_generated_tracked_paths() {
  local include_assets="${1:-false}"
  local include_pbxproj="${2:-true}"
  local paths_file="$TRINKET_GENERATED_OUTPUT_SCRIPT_DIR/config/generated-paths.tsv"

  TRACKED_PATHS=()
  while IFS='|' read -r kind path; do
    [[ -z "$kind" || "$kind" == \#* ]] && continue
    [[ "$kind" == project && "$include_pbxproj" != true ]] && continue
    [[ "$kind" == asset && "$include_assets" != true ]] && continue
    TRACKED_PATHS+=("$path")
  done < "$paths_file"
}

# Plan target UUIDs must be PBXNativeTarget IDs in the generated project.
assert_testplan_native_target_ids() {
  local pbx_ids plan_ids id
  pbx_ids="$(sed -n '/Begin PBXNativeTarget section/,/End PBXNativeTarget section/s/^[[:space:]]*\([A-F0-9]\{24\}\) \/\*.*/\1/p' Trinket.xcodeproj/project.pbxproj | sort -u)"
  plan_ids="$(grep -hoE '"identifier"[[:space:]]*:[[:space:]]*"[A-F0-9]{24}"' ./*.xctestplan | grep -oE '[A-F0-9]{24}' | sort -u)"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    if ! grep -qxF "$id" <<<"$pbx_ids"; then
      echo "ERROR: .xctestplan identifier $id is not a PBXNativeTarget in project.pbxproj" >&2
      return 1
    fi
  done <<<"$plan_ids"
}

print_tracked_diff_vs_head() {
  echo "--- Diff summary ---" >&2
  git status --porcelain=v1 --untracked-files=all -- "${TRACKED_PATHS[@]}" >&2 || true
  git diff --stat -- "${TRACKED_PATHS[@]}" >&2 || true
  git diff --cached --stat -- "${TRACKED_PATHS[@]}" >&2 || true
  echo "--- First 100 lines of diff ---" >&2
  git diff -- "${TRACKED_PATHS[@]}" | head -n 100 >&2 || true
  git diff --cached -- "${TRACKED_PATHS[@]}" | head -n 100 >&2 || true
}

# Committed-mode drift check over TRACKED_PATHS. Fails with triage output when
# tracked generated paths differ from HEAD.
trinket_assert_committed_output() {
  local tracked_status
  tracked_status="$(git status --porcelain=v1 --untracked-files=all -- "${TRACKED_PATHS[@]}")"
  if [[ -z "$tracked_status" ]]; then
    return 0
  fi
  echo "ERROR: Generated output is stale or uncommitted." >&2
  echo "If these are intentional task outputs, review them, commit or amend only the task scope, then rerun this gate." >&2
  echo "Otherwise run ./Scripts/generate.sh and investigate the unexpected drift (including Trinket.xcodeproj when project.yml changed)." >&2
  print_tracked_diff_vs_head
  return 1
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  return 0 2>/dev/null || true
fi

set -euo pipefail

cd "$(dirname "$0")/.."

REGENERATE=false
INCLUDE_ASSETS=false
STRICT_ASSETS=false
# committed: fail when tracked generated paths differ from HEAD (CI / pre-push).
# idempotent: regenerate once and fail if tracked outputs still change (local handoff).
MODE="committed"

usage() {
  cat <<'EOF'
Usage: ./Scripts/assert-generated-output.sh [options]

Checks that generated catalogs/assets match their manifests.

Modes:
  (default)        Commit completeness — tracked generated paths must match HEAD.
                   Use after generate on a clean checkout (CI, pre-push, ci-gate).
  --idempotent     Consistency — run generate once more; tracked outputs must not
                   change again. Use after generate in handoff (local/agent).

Options:
  --regenerate     Run ./Scripts/generate.sh before the committed-mode check
  --assets         Include art/music/SFX/cinematic outputs when regenerating or checking
  --strict-assets  With --assets/--idempotent, fingerprint full media trees (CI assets gate).
                   Default asset idempotence checks generated catalogs and hash TSVs only.
  --idempotent     Consistency check (see Modes); implies a regenerate pass
  -h, --help       Show this help

CI runs ./Scripts/generate.sh first, then this script without --regenerate.
handoff runs generate, then this script with --idempotent.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --regenerate)
      REGENERATE=true
      shift
      ;;
    --assets)
      INCLUDE_ASSETS=true
      shift
      ;;
    --strict-assets)
      INCLUDE_ASSETS=true
      STRICT_ASSETS=true
      shift
      ;;
    --idempotent)
      MODE="idempotent"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

trinket_set_generated_tracked_paths "$INCLUDE_ASSETS" true

run_generate() {
  if [[ "$INCLUDE_ASSETS" == true ]]; then
    ./Scripts/generate.sh --assets
  else
    ./Scripts/generate.sh
  fi
}

# Content fingerprint of tracked generated paths (files + trees). Stable across runs
# when generation is idempotent.
snapshot_tracked() {
  local path
  for path in "${TRACKED_PATHS[@]}"; do
    trinket_snapshot_path "$path"
  done
}

# Asset idempotence without hashing entire binary media trees. Per-asset hash TSVs
# are the correctness signal; catalogs must stay aligned with manifests.
snapshot_tracked_asset_catalogs() {
  local path
  for path in "${TRACKED_PATHS[@]}"; do
    case "$path" in
      Trinket/Media/*|Trinket/Assets.xcassets|Trinket/AppIcon.icon)
        continue
        ;;
    esac
    trinket_snapshot_path "$path"
  done
}

trinket_snapshot_path() {
  local path="$1"
  if [[ -d "$path" ]]; then
    find "$path" -type f ! -name '.DS_Store' -print0 \
      | LC_ALL=C sort -z \
      | xargs -0 shasum -a 256 2>/dev/null
  elif [[ -f "$path" ]]; then
    shasum -a 256 "$path"
  else
    printf 'MISSING %s\n' "$path"
  fi
}

snapshot_for_idempotent_check() {
  if [[ "$INCLUDE_ASSETS" == true && "$STRICT_ASSETS" != true ]]; then
    snapshot_tracked_asset_catalogs
  else
    snapshot_tracked
  fi
}

if [[ "$MODE" == "idempotent" ]]; then
  assert_testplan_native_target_ids

  # When handoff just stamped a fresh generate, skip the second full
  # generate if inputs are unchanged — still prove test-plan IDs and report.
  # shellcheck source=run-env.sh
  source ./Scripts/run-env.sh
  trinket_run_env_init
  # shellcheck source=build-inputs.sh
  source ./Scripts/build-inputs.sh
  stamp="${RESULTS_DIR}/.last-generate.stamp"
  skip_regenerate=false
  if [[ -f "$stamp" ]]; then
    content_changed="$(generation_paths_newer_than "$stamp" "${content_generation_inputs[@]}" || true)"
    project_changed="$(generation_paths_newer_than "$stamp" project.yml || true)"
    assets_changed=""
    if [[ "$INCLUDE_ASSETS" == true ]]; then
      assets_changed="$(generation_paths_newer_than "$stamp" "${asset_generation_inputs[@]}" || true)"
    fi
    # Prefer stamp-time porcelain over dirty-vs-HEAD. Agent/verify worktrees are
    # normally dirty after generate; re-checking HEAD dirtiness forced a second
    # full --assets generate + shasum pass (~30–50s) on every verify run.
    if [[ -z "$content_changed" && -z "$project_changed" ]] \
      && { [[ "$INCLUDE_ASSETS" != true ]] || [[ -z "$assets_changed" ]]; } \
      && assert_generate_input_git_snapshot_unchanged "$stamp"; then
      skip_regenerate=true
    fi
  fi

  if [[ "$skip_regenerate" == true ]]; then
    echo "Generated output stamp is fresh; skipping idempotent regenerate."
    echo "Generated output is stable under regenerate (matches manifests)."
    exit 0
  fi

  before="$(snapshot_for_idempotent_check)"
  run_generate
  after="$(snapshot_for_idempotent_check)"
  if [[ "$before" == "$after" ]]; then
    echo "Generated output is stable under regenerate (matches manifests)."
    # Align with verify/ci-gate so later wrappers skip generate.
    touch_generate_stamp "$RESULTS_DIR"
    exit 0
  fi
  echo "ERROR: Regenerating still changed tracked generated output." >&2
  echo "Generation is not idempotent, or another process mutated outputs mid-run." >&2
  if [[ "$INCLUDE_ASSETS" == true ]]; then
    echo "For art/music manifest edits, use ./Scripts/generate.sh --assets" >&2
  fi
  echo "" >&2
  # Show working-tree churn vs HEAD for triage (may include intentional uncommitted work).
  print_tracked_diff_vs_head
  exit 1
fi

if [[ "$REGENERATE" == true ]]; then
  run_generate
fi

assert_testplan_native_target_ids

if trinket_assert_committed_output; then
  echo "Generated output matches manifests (committed)."
  exit 0
fi

if [[ "$INCLUDE_ASSETS" == true ]]; then
  echo "For art/music manifest edits, use ./Scripts/generate.sh --assets" >&2
fi
exit 1
