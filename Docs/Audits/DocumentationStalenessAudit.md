# Documentation Staleness Audit

Goal: Fix misleading docs — stale paths, broken links, wrong versions, outdated claims.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

## Mission

Discover markdown from the repo (do not trust a hardcoded file count). Fix all **Critical** and **Moderate** issues found in this pass. Cap Roadmap `Status:` churn unless the user asked for a roadmap pass.

## Hard stops

- Do not hand-edit `CHANGELOG.md` (owned by `./Scripts/release.sh`).
- Do not treat dated “Last execution” / Done tables inside audits as source of truth — **delete** those tracker sections when found (audits must stay procedural).
- Do not rewrite design prose for style-only preferences.

## Discover targets

```bash
# Authoritative inventory — update nothing by hand-counting
find . -name '*.md' \
  -not -path './.DerivedData/*' \
  -not -path './.git/*' \
  -not -path './Raw Assets/*' \
  | sort

# Probes
rg -n '(Trinket/|Packages/|Scripts/|Docs/|ContentManifest/|ArtManifest/|MusicManifest/|SoundManifest/)' --type md -g '!.DerivedData/'
rg -n '\([^)]*\.md[#)]' --type md -g '!.DerivedData/'
rg -n 'https?://' --type md -g '!.DerivedData/'
rg -n '(iOS |Swift |Xcode |MARKETING_VERSION|CURRENT_PROJECT_VERSION|swift-tools-version)' --type md
rg -n '(currently|yet|not yet|in progress|eventually|so far|right now|at this point|phase \d|soon|upcoming|planned|scratch|parked)' --type md -i
rg -n '(Status:|R-\d{3}|Last execution|Last verified|\*\*Done\*\*|Audit run:)' --type md
```

Expect groups including: root (`README`, `AGENTS`, …), `Docs/` (Architecture, Roadmap, Design, **Platform**, Audits), package READMEs, manifest READMEs, `Scripts/README.md`.

## Workflow

1. Survey references (paths, types, links, versions, time-sensitive language)
2. Triage Critical / Moderate / Minor
3. Fix Critical + Moderate
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

- `test -f <path>` for every cited path
- `rg -l '\bTypeName\b' --type swift` for cited types
- Accessibility identifier strings must still exist in source

### Links

- Internal `.md` links resolve (`test -f`)
- Heading anchors still exist
- External URLs: spot-check Apple docs (expect 200/302)

### Versions / counts

- `AGENTS.md` / `README.md` iOS/Swift/Xcode match `project.yml` / toolchain
- Smoke class count: `ls TrinketUITests/Smoke/Smoke*.swift | wc -l` — update docs to the **current** number (do not assume 9)
- `Scripts/README.md` marketing version vs `project.yml`

### Terminology

Canonical names from `Docs/Architecture.md` / source: `AppTab` cases, `BattleSession` / `ActiveBattleConfiguration` / `BattleVictorySummary`, store names, manifest directory names (`SoundManifest/` included).

### Audit hygiene

- If an audit contains embedded run logs, Done tables, or “Last execution” trackers, remove them as part of this pass (restore procedural guide shape per [README.md](README.md)).

## Fixes

| Issue | Action |
|-------|--------|
| Deleted path / type | Update or delete the paragraph |
| Broken link | Fix target or remove |
| Stale version / count | Match source of truth |
| Time-sensitive language | Present-tense fact or remove |
| Inconsistent term | Prefer Architecture.md / source |
| Tracker residue in audits | Delete residue; keep probes/workflow |

## Verification

```bash
# Resolve relative .md links from repo root (skip http)
rg -o '\[[^\]]*\]\(([^)]+\.md)(#[^)]*)?\)' --type md -g '!.DerivedData/' -r '$1' \
  | sort -u | while read -r link; do
  case "$link" in http*|file:*) continue ;; esac
  # Links are relative to their source file — spot-check Audits/Platform/Architecture manually if needed
  test -f "$link" || echo "CHECK RELATIVE: $link"
done

ls -1 TrinketUITests/Smoke/Smoke*.swift | wc -l
rg -n 'iOS [0-9]|Swift [0-9]|MARKETING_VERSION' --type md -g '!.DerivedData/' | head -40
```

## Commit

```
docs(<scope>): <imperative subject>

- <specific fix>
- <specific fix>

User-Facing: no
```
