#!/usr/bin/env bash
set -euo pipefail
export GIT_OPTIONAL_LOCKS=0
cd "$(git rev-parse --show-toplevel)"
ROOT="$PWD"
source Scripts/lib/project-generation.sh

needed=false
while IFS= read -r -d '' path; do
  if [[ "$path" == Trinket.xcodeproj/project.pbxproj ]] || trinket_is_project_generation_input "$path"; then
    needed=true
    break
  fi
done < <(git diff --cached --name-only --no-renames -z)
[[ "$needed" == true ]] || exit 0

snapshot="$(mktemp -d "${TMPDIR:-/tmp}/trinket-staged-project.XXXXXX")"
trap 'rm -rf "$snapshot"' EXIT
cp "$(git rev-parse --git-path index)" "$snapshot/index"
export GIT_INDEX_FILE="$snapshot/index"

# Freeze the index without changing it. Exporting the tree also preserves deletions,
# file membership and partially staged inputs, independently of working-tree edits.
tree="$(git write-tree)"
mkdir "$snapshot/repo"
git archive "$tree" | tar -x -C "$snapshot/repo"

# Compare tool and hook files directly with the staged tree. A content comparison
# avoids trusting stale index stat metadata when a same-sized file changes quickly.
tool_paths=(
  Scripts/tool-versions.env
  Scripts/ensure-ci-tools.sh
  Scripts/lib/ci-tools.d
  Scripts/lib/tools.sh
  Scripts/lib/tool-install.sh
  Scripts/lib/project-generation.sh
  Scripts/check-staged-project.sh
  .githooks/pre-commit
)
for path in "${tool_paths[@]}"; do
  staged_path="$snapshot/repo/$path"
  working_path="$ROOT/$path"
  if [[ -e "$staged_path" || -e "$working_path" ]] && \
    ! git diff --no-index --quiet -- "$staged_path" "$working_path" >/dev/null 2>&1; then
    echo "Project check: resolve staged/unstaged tool or hook changes before retrying the commit." >&2
    exit 1
  fi
done

project=Trinket.xcodeproj/project.pbxproj
if [[ ! -f "$snapshot/repo/$project" ]]; then
  echo "Project check: regenerate with ./Scripts/generate.sh and stage $project before committing." >&2
  exit 1
fi
cp "$snapshot/repo/$project" "$snapshot/staged-project.pbxproj"
trinket_generate_project "$ROOT" "$snapshot/repo"
if ! cmp -s "$snapshot/staged-project.pbxproj" "$snapshot/repo/$project"; then
  echo "Project check: staged project does not match staged inputs." >&2
  echo "Edit authored inputs, run ./Scripts/generate.sh, and stage $project with its inputs before retrying." >&2
  exit 1
fi
echo "Staged project matches staged inputs."
