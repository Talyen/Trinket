#!/usr/bin/env bash
# Advisory authored-surface report; size warnings never fail the change.
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=Scripts/change-classification.sh
source Scripts/change-classification.sh

mode="working-tree"
base="HEAD"
declare -a requested=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      echo "Usage: ./Scripts/change-budget.sh [--base <rev>] [--paths <file> ...]"
      echo "Warning thresholds: TRINKET_BUDGET_{PROD_LOC,TEST_LOC,NEW_SWIFT,TYPE,TEST_DECL}_WARN"
      exit 0
      ;;
    --base)
      shift
      [[ $# -gt 0 ]] || { echo "--base requires a revision" >&2; exit 1; }
      base="$1"
      ;;
    --paths)
      mode="explicit"
      shift
      [[ $# -gt 0 ]] || { echo "--paths requires at least one path" >&2; exit 1; }
      requested=("$@")
      break
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
  shift
done

trinket_collect_paths "$mode" "${requested[@]-}"
if [[ ${#TRINKET_CHANGED_PATHS[@]} -eq 0 ]]; then
  echo "Change budget: no changes."
  exit 0
fi

stats=$(mktemp -t trinket-budget-stats.XXXXXX)
patch=$(mktemp -t trinket-budget-patch.XXXXXX)
trap 'rm -f "$stats" "$patch"' EXIT
git diff --no-renames --numstat "$base" -- "${TRINKET_CHANGED_PATHS[@]}" > "$stats"
git diff --no-renames --unified=0 "$base" -- "${TRINKET_CHANGED_PATHS[@]}" > "$patch"

# Git omits untracked files; append them as all-added synthetic diffs.
for path in "${TRINKET_CHANGED_PATHS[@]}"; do
  if [[ -f "$path" ]] && ! git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
    printf '%s\t0\t%s\n' "$(wc -l < "$path" | tr -d ' ')" "$path" >> "$stats"
    printf 'diff --git a/%s b/%s\n--- /dev/null\n+++ b/%s\n' "$path" "$path" "$path" >> "$patch"
    LC_ALL=C sed 's/^/+/' "$path" >> "$patch"
  fi
done

LC_ALL=C awk \
  -v rev="$base" \
  -v prod_limit="${TRINKET_BUDGET_PROD_LOC_WARN:-250}" \
  -v test_limit="${TRINKET_BUDGET_TEST_LOC_WARN:-150}" \
  -v file_limit="${TRINKET_BUDGET_NEW_SWIFT_WARN:-2}" \
  -v type_limit="${TRINKET_BUDGET_TYPE_WARN:-3}" \
  -v decl_limit="${TRINKET_BUDGET_TEST_DECL_WARN:-3}" '
  function category(p) {
    if (p ~ /(\/Generated\/|\.generated\.swift$|^Trinket\.xcodeproj\/|^\.DerivedData\/|^\.tools\/|^Raw Assets\/)/) return "generated"
    if (p ~ /(^TrinketUITests\/|\/Tests\/|^Scripts\/Tests\/)/) return "test"
    if (p ~ /(^Packages\/TrinketTestSupport\/|^Packages\/TrinketPersistence\/Sources\/TrinketPersistenceTestSupport\/)/) return "support"
    return p ~ /\.swift$/ ? "production" : "docs"
  }
  function declarations(text, copy, count) {
    copy = text; count = gsub(/@Test([[:space:](]|$)/, "", copy)
    return count + (text ~ /func[[:space:]]+test[A-Za-z0-9_]*[[:space:]]*\(/)
  }
  function warning(message) {
    if (!warnings++) print "  Warnings:"
    print "    - " message
  }
  FNR == NR {
    added = $1 == "-" ? 0 : $1; deleted = $2 == "-" ? 0 : $2
    path = $0; sub(/^[^\t]*\t[^\t]*\t/, "", path); kind = category(path)
    if (kind == "production") { pa += added; pd += deleted }
    else if (kind == "test" || kind == "support") { ta += added; td += deleted }
    else if (kind == "docs") { da += added; dd += deleted }
    else generated++
    next
  }
  /^diff --git / { new_file = 0; next }
  /^--- \/dev\/null/ { new_file = 1; next }
  /^--- a\// { path = substr($0, 7); kind = category(path); next }
  /^\+\+\+ b\// {
    path = substr($0, 7); kind = category(path)
    if (new_file && path ~ /\.swift$/) { if (kind == "production") new_prod++; else if (kind == "test" || kind == "support") new_test++ }
    next
  }
  /^\+\+\+|^@@/ { next }
  /^\+[^+]/ {
    text = substr($0, 2)
    if (kind == "production" && text ~ /(^|[^A-Za-z0-9_])(class|struct|enum|protocol|actor)[[:space:]]+[A-Za-z_]/) types_added++
    if (kind == "test" || kind == "support") tests_added += declarations(text)
    next
  }
  /^-[^-]/ {
    text = substr($0, 2)
    if (kind == "production" && text ~ /(^|[^A-Za-z0-9_])(class|struct|enum|protocol|actor)[[:space:]]+[A-Za-z_]/) types_deleted++
    if (kind == "test" || kind == "support") tests_deleted += declarations(text)
  }
  END {
    pn = pa - pd; tn = ta - td; dn = da - dd; typen = types_added - types_deleted; testn = tests_added - tests_deleted
    print "Change budget (advisory vs " rev "):"
    printf "  Production Swift: +%d/-%d (net %+d), new files %d, types +%d/-%d\n", pa, pd, pn, new_prod, types_added, types_deleted
    printf "  Test Swift:       +%d/-%d (net %+d), new files %d, declarations +%d/-%d\n", ta, td, tn, new_test, tests_added, tests_deleted
    printf "  Docs/tools:       +%d/-%d (net %+d)\n", da, dd, dn
    if (generated) printf "  Generated/processed: %d changed path(s), excluded\n", generated
    if (pn > prod_limit) warning("production growth exceeds +" prod_limit " LOC; explain necessity and the simpler rejected alternative")
    if (tn > test_limit) warning("test growth exceeds +" test_limit " LOC; confirm unique semantic ownership")
    if (new_prod > file_limit) warning("more than " file_limit " production Swift files were added; confirm each owner")
    if (typen > type_limit) warning("net production type growth exceeds +" type_limit "; check helper/wrapper/manager ceremony")
    if (testn > decl_limit) warning("net test declarations exceed +" decl_limit "; confirm the test-addition gate")
    if (ta || td) print "  Runtime note: declarations exclude expanded argument cases; inspect test-timing.sh for affected owners."
    if (!warnings) print "  Warnings: none"
  }
' "$stats" "$patch"

# Advisory: production Swift in a package with no matching test-path edits.
prod_packages=""
test_packages=""
for path in "${TRINKET_CHANGED_PATHS[@]}"; do
  [[ "$path" == *.swift ]] || continue
  [[ "$path" == */Generated/* || "$path" == *.generated.swift ]] && continue
  case "$path" in
    Packages/*/Tests/*)
      package="${path#Packages/}"
      test_packages+="${package%%/*}"$'\n'
      ;;
    Packages/*/Sources/*)
      package="${path#Packages/}"
      prod_packages+="${package%%/*}"$'\n'
      ;;
  esac
done
missing=()
while IFS= read -r package; do
  [[ -z "$package" ]] && continue
  if ! printf '%s' "$test_packages" | grep -Fxq "$package"; then
    missing+=("$package")
  fi
done < <(printf '%s' "$prod_packages" | LC_ALL=C sort -u)
if ((${#missing[@]} > 0)); then
  echo "  Package test coverage:"
  for package in "${missing[@]}"; do
    echo "    - production Swift in ${package} changed with no test path in that package"
  done
fi
