# Documentation Staleness Audit

Goal: Zero documentation that misleads — every `.md` file matches actual code, architecture, workflow, and project state. Fix or flag every stale reference, broken link, wrong assumption, and outdated claim.

You are working on Trinket, a portrait-first iOS fantasy idle auto-battler (Swift 6 / SwiftUI, iOS 26). Read `AGENTS.md` and `Docs/Architecture.md` first.

## Targets

All 31 markdown files in the repository:

| Group | Files |
|-------|-------|
| Root | `README.md` `AGENTS.md` `CHANGELOG.md` `LICENSE.md` |
| Docs | `Docs/Architecture.md` `Docs/Roadmap.md` |
| Docs/Design | `Docs/Design/CoreDesignConcepts.md` `Docs/Design/AppleNativeGuidelines.md` `Docs/Design/StyleGuide/AppVisualFoundation.md` `Docs/Design/StyleGuide/VisualReferences/README.md` |
| Docs/Audits | `Docs/Audits/BehaviorHardeningAudit.md` `Docs/Audits/CloudKitPreShipChecklist.md` `Docs/Audits/ComplexityReductionAudit.md` `Docs/Audits/DeadCodeRatioAudit.md` `Docs/Audits/ImportCouplingBoundaryAudit.md` `Docs/Audits/SideEffectSurfaceAudit.md` `Docs/Audits/TestQualityAudit.md` `Docs/Audits/TypeSafetyAudit.md` `Docs/Audits/UIInteractionFeedbackAudit.md` `Docs/Audits/DocumentationStalenessAudit.md` |
| Packages | `Packages/TrinketCore/README.md` `Packages/TrinketContent/README.md` `Packages/BattleEngine/README.md` `Packages/TrinketPersistence/README.md` `Packages/TrinketDesignSystem/README.md` |
| Package tests | `Packages/BattleEngine/Tests/README.md` `Packages/TrinketContent/Tests/README.md` `Packages/TrinketPersistence/Tests/README.md` |
| Manifests | `ContentManifest/README.md` `ArtManifest/README.md` `MusicManifest/README.md` |
| Scripts | `Scripts/README.md` |

**Script probes:**

```bash
# Find all file-path references in markdown
rg -n '(Trinket/|Packages/|Scripts/|Docs/|ContentManifest/|ArtManifest/|MusicManifest/)' --type md -g '!.DerivedData/'

# Find all internal cross-doc links
rg -n '\([^)]*\.md[#)]' --type md -g '!.DerivedData/'

# Find all external URLs
rg -n 'https?://' --type md -g '!.DerivedData/'

# Find all version numbers
rg -n '(iOS |Swift |Xcode |MARKETING_VERSION|CURRENT_PROJECT_VERSION|swift-tools-version)[: ]*[0-9]' --type md

# Find time-sensitive language
rg -n '(currently|yet|not yet|in progress|eventually|so far|right now|at this point|phase \d|soon|upcoming|planned|scratch|parked)' --type md -i

# Find roadmap status fields
rg -n '(Status:|R-\d{3})' --type md
```

## Workflow

1. **Survey** — Process all 31 `.md` files. For each file, catalog every:
   - Code reference: file path, type name, function signature, enum case, property, test class
   - Internal cross-reference: both linked `[text](path.md)` and plain-text "see X.md"
   - External URL
   - Version number or version-dependent claim (iOS, Swift, Xcode, tools-version, marketing version)
   - Time-sensitive statement (`currently`, `not yet`, `in progress`, `eventually`, `phase`)
   - Status field (roadmap `R-NNN` entries, `Status:` tags)
   - Accessibility identifier string value
   - Hardcoded count or timing estimate

2. **Triage** — Classify each issue by severity:

   | Severity | Criteria |
   |----------|----------|
   | 🔴 Critical | Wrong API name, deleted file path, stale architecture assumption, broken link, wrong version constraint |
   | 🟡 Moderate | Stale version number, inaccurate count, "in progress" for completed work, roadmap status not updated |
   | 🔵 Minor | Typo, formatting, stale "see also" to a still-reachable doc, missing language tag on code block |

3. **Fix** — Address all 🔴 and 🟡 issues per § Fixes.

4. **Verify** — Run verification from § Verification.

## Checks

### 1. Stale code references

For every file path, type name, function/method signature, enum case, property name, test class, and script name mentioned in prose:

- `ls <path>` or `git ls-tree HEAD -r --name-only | grep <path>` — confirm the file path still exists
- `rg -l '\b<TypeName>\b' --type swift -g '!*Tests*' -g '!**/Generated/*'` — confirm the type still exists in source
- `rg -l '\b<ScriptName>\b' --type sh` — confirm the script still exists
- `rg '<enumCase>' --type swift -g '!*Tests*' -g '!**/Generated/*'` — confirm enum case not removed or renamed
- `rg -l '\b<AccessibilityID>\b' --type swift` — confirm accessibility identifier values match source

### 2. Broken internal cross-links

For every `[text](relative/path.md)` and every plain-text reference like "see `Docs/Architecture.md`":

- `test -f <resolved-path>` — confirm the target file exists
- If the link has a heading anchor (`#section-name`), use `rg '^#+.*section-name' <file>` to confirm the heading still exists
- For cross-references between audit files, confirm the referenced section still exists

### 3. Broken external URLs

For all external URLs across the repo:

- `curl -o /dev/null -s -w '%{http_code}' <url>` — should return 200 or 302, not 404/410/5xx
- Apple HIG links (`developer.apple.com/design/human-interface-guidelines/...`) — Apple occasionally reorganizes; manually verify redirect targets are valid
- `https://github.com/yonaskolb/XcodeGen` — confirm the repo is not archived or deleted

### 4. Outdated version / platform / status information

Check these file-by-file:

- **`AGENTS.md`**: `iOS 26.0` / `Swift 6.0` — match against current `project.yml` and `Package.swift`; "9 Smoke* UI classes only (~2 min)" — count actual `Smoke*.swift` files with `ls TrinketUITests/Smoke/Smoke*.swift | wc -l`; `UI_PARALLEL_WORKERS=3` — match current default
- **`README.md`**: `Xcode 26+` / `Swift 6.0` — match current toolchain; `sudo xcode-select --switch` path — verify it is still correct
- **`Docs/Architecture.md`**: `iOS 26.0, Swift 6.0` / `swift-tools-version: 6.2` — match current; `SpriteKit is not in use yet` — confirm this is still true; ✅ checklist items — verify each is truly completed
- **`Scripts/README.md`**: `MARKETING_VERSION: "0.1.0"` — match against `project.yml`; `Phase 3: TestFlight / App Store automation` — update if any part has been implemented
- **`Docs/Roadmap.md`**: All 25 `R-NNN` entries — update each `Status:` field to current (`shipped`, `parked`, `scratch`, `planned`, `exploring`)

### 5. Wrong assumptions / time-sensitive language

Every instance of these phrases needs evaluation:

- `currently` — is it still current?
- `not yet` / `yet` — has the referenced item since landed?
- `in progress` — completed, cancelled, or still active?
- `eventually` / `future work` / `planned` — still an accurate intent, or stale?
- `at this point` / `so far` / `right now` — evaluate for staleness
- `after the ... migration` — is the migration complete?
- `before their full systems exist` — have the systems since landed?

### 6. Inconsistent terminology across docs

Cross-doc naming audit — each concept should use the same name everywhere:

- Collection tab surface: `PlayerCollectionState` / Roster / Heroes / Pets / Inventory — verify consistent across `AGENTS.md`, `CoreDesignConcepts.md`, `Architecture.md`
- Tab enum: `AppTab` case names — verify `README.md`, `AGENTS.md`, and `Docs/Architecture.md` all agree (`.play`, `.collection`, `.homestead`, `.search`, `.options`)
- Battle orchestration: `BattleSession` / `ActiveBattleConfiguration` / `BattleVictorySummary` — verify consistent use across all docs
- Store names: `PlayerSaveStore` / `PlayerRosterStore` / `PlayerInventoryStore` / `PlayerJourneyStore` — verify names match current source
- Manifest terminology: `ContentManifest/` vs `ArtManifest/` vs `MusicManifest/` vs `SoundManifest/` — verify references match actual directory names

### 7. Markdown rendering issues

- Every code block specifies a language (````swift`, ````sh`, ````text`, ````bash`) — no orphaned ` ``` `
- All tables are well-formed with matching column counts in header and body rows
- Lists are consistently indented with the same marker style throughout a file (no mixed `-` and `*`)
- Headings follow a proper hierarchy (`#` → `##` → `###`, no level jumps)
- No broken inline code spans (backticks are properly matched)

### 8. Stale generated output / manifest references

- `Generated/` file paths referenced in docs — run `./Scripts/generate.sh` and confirm the referenced files are still produced
- Manifest paths (`ContentManifest/stages.tsv`, `ArtManifest/curated-assets.tsv`, `MusicManifest/music.tsv`, `SoundManifest/sfx.tsv`) — confirm each manifest file still exists
- Pipeline descriptions in `Docs/Architecture.md` data-flow boxes — confirm each step's script path and output path still match reality

## Fixes

| Issue type | Fix |
|------------|-----|
| Deleted or renamed file path | Update to current path; delete the paragraph if the referenced concept no longer exists |
| Wrong type, enum, or function name | Update to current name from source |
| Broken internal link | Update link target or remove the reference |
| Broken external URL | Replace with updated Apple URL; remove dead links that have no replacement |
| Stale version number | Bump to current value from `project.yml` / `Package.swift` |
| Stale roadmap status | Update `Status:` field: `shipped` for completed, `parked` for abandoned, `planned` for active work |
| Time-sensitive language | Replace with factual present-tense statement or remove the paragraph |
| Inconsistent terminology | Pick the canonical name (check `Docs/Architecture.md` or source) and apply everywhere |
| Hardcoded count or estimate | Update to exact current count; delete timing estimates |
| Markdown formatting error | Fix language tag, table alignment, list consistency, heading hierarchy |
| Stale generated path | Re-run `./Scripts/generate.sh --assets` if manifest changed; otherwise update the doc path |
| Missing or aspirational feature | Add note linking to the corresponding roadmap item; delete aspirational prose from non-roadmap docs |
| Roadmap shipped item | Move the completed item's prose from `Docs/Roadmap.md` into the relevant design doc; update `Status: shipped` |

Do **not** hand-edit `CHANGELOG.md` — that file is maintained by `./Scripts/release.sh`.

## Verification

```bash
# Internal links — confirm every .md link resolves (using standard, portable grep/rg)
rg -o '\([^)]+\.md[#)]' --type md -g '!.DerivedData/' | \
  sed -e 's/^[^(]*(//' -e 's/[)#].*//' | sort -u | while read -r link; do
  # Skip absolute file:/// links or web URLs
  if [[ "$link" =~ ^(file:|http:|https:) ]]; then continue; fi
  test -f "$link" || echo "MISSING: $link"
done

# External URLs — quick HTTP check (manual spot-check for Apple docs)
# Version consistency — grep all version references and cross-check
grep -rn 'iOS [0-9]' --type md -g '!.DerivedData/' -h
grep -rn 'Swift [0-9]' --type md -g '!.DerivedData/' -h
grep -rn 'MARKETING_VERSION' --type md -g '!.DerivedData/' -h
# Manually verify all match current project.yml / Package.swift

# Count validation
ls -1 TrinketUITests/Smoke/Smoke*.swift | wc -l
# Update AGENTS.md if the count differs from "9 Smoke* UI classes"
```

*Note: For long-term documentation health, consider setting up a link-validation build phase script (e.g. `Scripts/validate-markdown-links.sh`) or a git pre-commit hook to catch broken internal links automatically.*

Commit with this format:

```
docs(<scope>): <imperative subject>

- <specific fix>
- <specific fix>

User-Facing: no
```

## Reference audits

Consult these sibling audits when their concern overlaps with a fix:

- `Docs/Audits/TypeSafetyAudit.md` — if changing code references to type-safe alternatives
- `Docs/Audits/DeadCodeRatioAudit.md` — if deleting orphaned doc references to dead code
- `Docs/Audits/BehaviorHardeningAudit.md` — if updating doc references to store/sync APIs
