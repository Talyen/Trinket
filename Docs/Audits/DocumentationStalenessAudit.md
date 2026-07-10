# Documentation Staleness Audit

Goal: Fix misleading docs — stale paths, broken links, wrong versions, outdated claims.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

## Mission

Discover markdown from the repository (do not trust a hardcoded file count). Fix confirmed Critical and Moderate drift within one coherent doc area or a modest blast radius. A pass with no contradiction is valid.

## Hard stops

- Do not hand-edit `CHANGELOG.md` (owned by `./Scripts/release.sh`).
- Do not treat dated “Last execution” / Done tables inside audits as source of truth — **delete** those tracker sections when found (audits must stay procedural).
- Do not rewrite design prose for style-only preferences.
- Do not turn this into a repo-wide docs rewrite — triage and cap.

## Discover targets

```bash
# Authoritative inventory — respects agent do-not-read trees
rg --files -g '*.md' \
  -g '!**/.git/**' -g '!**/.DerivedData/**' -g '!**/.build/**' \
  -g '!**/.tools/**' -g '!**/Generated/**' -g '!Raw Assets/**' | sort

# Probes
rg -n '(Trinket/|Packages/|Scripts/|Docs/|ContentManifest/|ArtManifest/|MusicManifest/|SoundManifest/)' --type md -g '!**/.DerivedData/**' -g '!**/.build/**' -g '!**/.tools/**' -g '!**/Generated/**' -g '!Raw Assets/**'
rg -n '\([^)]*\.md[#)]' --type md -g '!**/.DerivedData/**' -g '!**/.build/**' -g '!**/.tools/**' -g '!**/Generated/**' -g '!Raw Assets/**'
rg -n 'https?://' --type md -g '!**/.DerivedData/**' -g '!**/.build/**' -g '!**/.tools/**' -g '!**/Generated/**' -g '!Raw Assets/**'
rg -n '(iOS |Swift |Xcode |MARKETING_VERSION|CURRENT_PROJECT_VERSION|swift-tools-version)' --type md -g '!**/.DerivedData/**' -g '!**/.build/**' -g '!**/.tools/**' -g '!**/Generated/**' -g '!Raw Assets/**'
rg -n '(currently|yet|not yet|in progress|eventually|so far|right now|at this point|phase \d|soon|upcoming|planned|scratch|parked)' --type md -i -g '!**/.DerivedData/**' -g '!**/.build/**' -g '!**/.tools/**' -g '!**/Generated/**' -g '!Raw Assets/**'
rg -n '(Status:|R-\d{3}|Last execution|Last verified|\*\*Done\*\*|Audit run:)' --type md -g '!**/.DerivedData/**' -g '!**/.build/**' -g '!**/.tools/**' -g '!**/Generated/**' -g '!Raw Assets/**'
```

Expect groups including: root (`README`, `AGENTS`, …), `Docs/` (**Platform**, AgentContext, Audits, Skills, Plans, Product), package READMEs, manifest READMEs, `Scripts/README.md`.

## Workflow

1. Survey references (paths, types, links, versions, time-sensitive language)
2. Triage Critical / Moderate / Minor
3. Fix Critical + Moderate within the blast-radius cap
4. Verify
5. Commit — do not write results into this file

## Severity

| Level | Criteria |
|-------|----------|
| Critical | Wrong API/path, broken link, stale architecture assumption, wrong version constraint |
| Moderate | Wrong count, “in progress” for finished work, inconsistent terminology |
| Minor | Typo, formatting, missing code-fence language |

## Checks

### Code references

- `test -f <path>` for every cited path (from repo root for absolute-style paths)
- `rg -l '\bTypeName\b' --type swift` for cited types
- Accessibility identifier strings must still exist in source

### Links

- Internal `.md` links must resolve **relative to the source file** (not only from repo root)
- Heading anchors still exist
- External URLs: check only when the cited source is being changed and network access is available; do not fail solely on an unavailable or bot-protected endpoint

### Versions / counts (sources of truth)

- `AGENTS.md` / `README.md` iOS/Swift/Xcode match `project.yml` (`deploymentTarget`, `SWIFT_VERSION`) / toolchain
- Package `swift-tools-version` in `Packages/*/Package.swift` may be newer than language “Swift 6” wording — docs should not claim a tools version that contradicts the packages
- Smoke class count: `ls TrinketUITests/Smoke/Smoke*.swift | wc -l` — update docs to the **current** number (do not assume a fixed count)
- `Scripts/README.md` marketing version vs `project.yml`

### Terminology

Canonical names from `Docs/Platform/Architecture.md` / source: `AppTab` cases, `BattleSession` / `ActiveBattleConfiguration` / `BattleVictorySummary`, store names, manifest directory names (`SoundManifest/` included).

### Audit hygiene

- If an audit contains embedded run logs, Done tables, or “Last execution” trackers, remove them as part of this pass (restore procedural guide shape per [README.md](README.md)).

## Fixes

| Issue | Action |
|-------|--------|
| Deleted path / type | Update or delete the paragraph |
| Broken link | Fix target or remove |
| Stale version / count | Match source of truth |
| Time-sensitive language contradicted by source | Present-tense fact or remove |
| Inconsistent term | Prefer Architecture.md / source |
| Tracker residue in audits | Delete residue; keep probes/workflow |

## Verification

```bash
# Resolve .md links relative to each source file (skip http)
python3 - <<'PY'
import os, re, sys
root = os.getcwd()
pat = re.compile(r'\[[^\]]*\]\(([^)]+)\)')
broken = []
for dirpath, _, files in os.walk(root):
    if any(p in dirpath for p in ('/.git', '/.DerivedData', '/.build', '/.tools', '/Generated', '/Raw Assets')):
        continue
    for name in files:
        if not name.endswith('.md'):
            continue
        path = os.path.join(dirpath, name)
        text = open(path, encoding='utf-8', errors='replace').read()
        for m in pat.finditer(text):
            link = m.group(1).split()[0]  # drop optional title
            if link.startswith(('http://', 'https://', 'mailto:', '#')):
                continue
            target, _, _ = link.partition('#')
            if not target:
                continue
            resolved = os.path.normpath(os.path.join(dirpath, target))
            if not os.path.isfile(resolved):
                broken.append(f"{os.path.relpath(path, root)} -> {link}")
for b in broken[:50]:
    print(b)
print(f"broken_count={len(broken)}")
sys.exit(1 if broken else 0)
PY

ls -1 TrinketUITests/Smoke/Smoke*.swift | wc -l
rg -n 'deploymentTarget|SWIFT_VERSION' project.yml | head -20
rg -n 'swift-tools-version' Packages/*/Package.swift
rg -n 'iOS [0-9]|Swift [0-9]|MARKETING_VERSION' --type md -g '!.DerivedData/' | head -40
```

## Commit

```
docs(<scope>): <imperative subject>

- <specific fix>
- <specific fix>

User-Facing: no
```
