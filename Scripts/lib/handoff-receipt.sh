#!/usr/bin/env bash
# Content-addressed handoff receipt: lets push gates reuse a green handoff
# without re-running the expensive package/style work.
#
# Receipt is keyed by the git tree hash of the verified state, so a commit
# that contains exactly the working tree handoff verified can skip duplicates.
# No timestamp trust: reuse requires tree equality and identical classification.

_trinket_handoff_receipt_path() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd))"
  printf '%s/.DerivedData/handoff-receipt.json' "$root"
}

trinket_handoff_receipt_write() {
  local receipt_path
  receipt_path="$(_trinket_handoff_receipt_path)"
  mkdir -p "$(dirname "$receipt_path")"

  local head tree paths_hash timestamp
  head="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)"

  # Compute verified tree: HEAD^{tree} if clean, otherwise the tree of the
  # working state handoff just verified (staged + unstaged + untracked).
  tree="$(git rev-parse HEAD^{tree} 2>/dev/null || echo unknown)"
  local dirty=false
  if ! git diff --quiet 2>/dev/null; then dirty=true; fi
  if ! git diff --cached --quiet 2>/dev/null; then dirty=true; fi
  if [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null | head -n 1)" ]]; then dirty=true; fi
  if [[ "$dirty" == true ]]; then
    local tmp_index
    tmp_index="$(mktemp 2>/dev/null || echo /tmp/trinket-handoff-index-$$)"
    if cp .git/index "$tmp_index" 2>/dev/null; then :; else rm -f "$tmp_index"; tmp_index=""; fi
    if [[ -n "$tmp_index" && -f "$tmp_index" ]]; then
      GIT_INDEX_FILE="$tmp_index" git add -A 2>/dev/null || true
      local wt_tree
      wt_tree="$(GIT_INDEX_FILE="$tmp_index" git write-tree 2>/dev/null || echo "")"
      if [[ -n "$wt_tree" ]]; then tree="$wt_tree"; fi
      rm -f "$tmp_index"
    fi
  fi

  # Hash of the classification input (sorted changed paths) for stricter matching.
  paths_hash="$(printf '%s\n' "${TRINKET_CHANGED_PATHS[@]-}" | sort -u | shasum -a 256 2>/dev/null | awk '{print $1}' || echo unknown)"
  local packages_json verification_json
  # Build JSON arrays from bash arrays (empty -> []).
  packages_json="$(printf '%s\n' "${TRINKET_PACKAGES[@]-}" | awk 'NF{printf "\"%s\",",$0} END{print ""}' | sed 's/,$//' )"
  verification_json="$(printf '%s\n' "${TRINKET_VERIFICATION_COMMANDS[@]-}" | awk '{gsub(/"/,"\\\""); printf "\"%s\",",$0} END{print ""}' | sed 's/,$//' )"

  cat > "$receipt_path" <<JSON
{
  "version": 1,
  "head": "$head",
  "tree": "$tree",
  "paths_hash": "$paths_hash",
  "packages": [${packages_json}],
  "verification": [${verification_json}],
  "needs_style": ${TRINKET_NEEDS_STYLE:-false},
  "needs_generate": $( [[ "${TRINKET_NEEDS_CONTENT_GENERATION:-false}" == true || "${TRINKET_NEEDS_PROJECT_GENERATION:-false}" == true || "${TRINKET_NEEDS_ASSET_GENERATION:-false}" == true ]] && echo true || echo false ),
  "timestamp": "$timestamp"
}
JSON
}

# Returns 0 if receipt matches current HEAD tree and covers the required
# packages/style classification. Prints a short reason on stdout when skipping.
trinket_handoff_receipt_can_skip() {
  local kind="$1"
  local receipt_path
  receipt_path="$(_trinket_handoff_receipt_path)"
  if [[ ! -f "$receipt_path" ]]; then return 1; fi

  local current_tree receipt_tree
  current_tree="$(git rev-parse HEAD^{tree} 2>/dev/null || echo unknown)"
  receipt_tree="$(python3 -c "import json;print(json.load(open('$receipt_path')).get('tree',''))" 2>/dev/null || echo unknown)"
  if [[ "$current_tree" == unknown || "$receipt_tree" == unknown ]]; then return 1; fi
  if [[ "$current_tree" != "$receipt_tree" ]]; then return 1; fi

  # Receipt must have been produced for a handoff that included the same
  # package/style needs as the current classification.
  case "$kind" in
    style)
      local needs_style receipt_needs_style
      needs_style="${TRINKET_NEEDS_STYLE:-false}"
      receipt_needs_style="$(python3 -c "import json;print(str(json.load(open('$receipt_path')).get('needs_style',False)).lower())" 2>/dev/null || echo false)"
      if [[ "$needs_style" == true && "$receipt_needs_style" != true ]]; then return 1; fi
      ;;
    package)
      # Every package the push wants must have been in the receipt.
      if (( ${#TRINKET_PACKAGES[@]} > 0 )); then
        local pkg
        for pkg in "${TRINKET_PACKAGES[@]}"; do
          [[ -n "$pkg" ]] || continue
          if ! python3 -c "import json,sys;data=json.load(open('$receipt_path'));sys.exit(0 if '$pkg' in data.get('packages',[]) else 1)" 2>/dev/null; then
            return 1
          fi
        done
      fi
      ;;
    generate)
      # Generate reuse only if receipt already verified generation.
      local receipt_needs_generate
      receipt_needs_generate="$(python3 -c "import json;print(str(json.load(open('$receipt_path')).get('needs_generate',False)).lower())" 2>/dev/null || echo false)"
      local current_needs_generate=false
      if [[ "${TRINKET_NEEDS_CONTENT_GENERATION:-false}" == true || "${TRINKET_NEEDS_PROJECT_GENERATION:-false}" == true || "${TRINKET_NEEDS_ASSET_GENERATION:-false}" == true ]]; then
        current_needs_generate=true
      fi
      if [[ "$current_needs_generate" == true && "$receipt_needs_generate" != true ]]; then return 1; fi
      # Also ensure generated files are still idempotent; caller will check.
      ;;
    *)
      return 1
      ;;
  esac

  return 0
}
