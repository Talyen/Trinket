# Content and manifest context

Read the shared safeguards and the section for the changed input. Column formats
live in each manifest directory's README; open only the relevant one.

## Shared safeguards

Edit authored inputs (manifests, ability Swift, `ContentManifest/talents.tsv`, or the relevant `Scripts/internal/content/trigger_families/*.json`). Do not hand-edit generated Swift, generated inventory TSV, processed assets/resources, or the Xcode project. The verification router owns generation and idempotence.

Catalog inputs and generated outputs must stay in sync. Review generated changes
against authored inputs; generation must be idempotent. For generated talent, affix,
and Homestead catalogs, `agent-diff.py --summary --paths <generated-files...>`
provides bounded record/field hints and discloses unrecognized changes. Generated files are committed
so the app builds without rerunning generation. Routine local handoff defers
content/project generation and idempotence to CI; pre-push checks committed-output
completeness. CI regenerates content/project outputs and compares them against
HEAD, including idempotence. Media preparation stays local; CI and the selected
lightweight handoff check receipt-bound prepared outputs without raw sources.

The router owns verification selection. Content manifests require generation and
idempotence; media manifests use the [media preparation contract](#media-assets).
Semantic content changes use content tests; Swift adds style checks.
Commit staging follows [Release](../Platform/Release.md#local-hooks-and-push-discipline).

## Abilities

**Abilities:** author only in the authored catalog Swift under `Packages/TrinketContent/Sources/TrinketContent/Abilities/`. To list or understand abilities, use `AbilityCatalog.all` or the generated inventory; there is no authored abilities TSV.

Ability declarations and ordered tier lists live in `AbilityCatalog+Basic.swift`,
`AbilityCatalog+Skill.swift`, and `AbilityCatalog+Ultimate.swift`. The catalog facade
combines those lists; preserve their order and existing IDs. Use
`python3 Scripts/content-inspect.py --kind abilities --id <id>` for the authored location.

`Ability` shares immutable storage across combat snapshots. Its value payload owns
all definition fields and synthesized equality/hash behavior. Combat transformations
copy that payload and edit only their changed fields; avoid rebuilding a definition
by forwarding every field, which can silently drop newly added mechanics.
Generated descriptions, gameplay/identity keywords, and presentation keywords are cached lazily in that storage.
Keep caches outside value equality/hashing; transformations must receive fresh storage
so empowered or resolved cards cannot reuse the original card's text or keywords.

`AbilityValidator` inspects base, random-branch, and conditional operations through
one traversal. Keep alternatives separate when totaling tier damage; both normal
attack targets and explicit enemy targets count. Cleansing (including Panacea)
targets allies, while purge targets enemies. `AbilityValidationTests` owns these
checks; `AbilityCatalogTests` owns catalog identity and player-facing descriptions.

## Manifests

**Talents:** author in `ContentManifest/talents.tsv` using the affix trigger/modifier DSL. Keep lookup/config in `CombatantTalentCatalog.swift`; generated dictionaries are outputs. See `ContentManifest/README.md`.

**Enemy traits:** author in `ContentManifest/traits.tsv` (same DSL); generated catalogs are outputs.

For exact manifest inspection, use `python3 Scripts/content-inspect.py --id <id>`;
`--name <text>` finds player-facing names without first knowing the saved ID.
`--trigger <canonicalField>` finds entries using that trigger through the same DSL
parser as generation. Results identify authored locations and disclose omitted
records/shortened fields; follow pagination or `--full` to expand. `--references`
follows parsed trigger fields and modifier cases to schema locations, focused talent
rule anchors, authored Swift references, and tests for the displayed record page.
These are literal hints, not a semantic consumer graph. `--reference-limit` and
`--reference-offset` page those hints independently; follow the printed continuation.

## Trigger schemas

Trigger definitions live one family per JSON under `Scripts/internal/content/trigger_families/`;
`index.json` preserves generation order. Edit the relevant family, not the index,
for a field change. `Scripts/internal/content/modifiers.json` owns modifier DSL
names, Swift cases, numeric kinds and keyword arguments. It generates the
`AffixModifier` enum and mechanical transforms; gameplay application, presentation,
and magnitude bump policy remain authored. Preserve case names, associated-value
shapes, and Codable representations when evolving these definitions.
Validation checks Swift identifiers, typed defaults, type-compatible merge operations,
and 64-bit `Int` bounds before rendering trigger/modifier literals.

Trigger fields used by affixes require `affix_roll` metadata in their family JSON:
`{"kind": "int" | "percent", "order": N}` for rollable values, or
`{"reason": "..."}` for deliberate exclusions. Orders are unique and nonnegative;
preserve existing orders and append new rollable fields so seeded roll/bump
selection stays stable. Generation owns the typed field list and exclusion reasons;
rolling behavior, numeric text replacement, and gameplay remain authored.

Affix scaling, rolling, and corruption share the ordered magnitude traversal in
`ItemAffixPower+Rolling.swift`. Bind description numbers against the original text,
including unchanged fields, so equal magnitudes and replacement collisions retain
their field ownership. Corruption availability and candidate selection share one
lazy eligibility filter. Preserve this order and the existing numeric/save formats.

## Media assets

Shared media-pipeline rules: raw source folders in the external Asset Library are not in Xcode target membership; processed outputs under
`Trinket/` are. Hash-based media pipelines re-encode when source bytes or encode settings
change; set `FORCE_ASSET_REENCODE=1` to rebuild regardless of cached state.

Each `prepare-<media>-assets.sh` is that pipeline's focused debugging entry point.
Use `./Scripts/prepare-assets.sh` (or `generate.sh --assets`) locally for media inputs. Both games default to `~/Documents/Asset Library`; override with `ASSET_LIBRARY_ROOT`. Source paths in manifests are library-relative. Artwork lives under shared Characters, Actions, Items, Places, Interface, Animation, and Branding folders. Subject folders group portrait/landscape and facing variants; the manifest selects the exact master. Game names remain in intrinsically branded filenames, not ownership folders. Adding unselected library files cannot change shipping inventories; new revisions use distinct filenames and explicit manifest adoption. App-icon sources are selected in `ArtManifest/app-icon.tsv`.

`./Scripts/prepare-assets.sh --check` verifies local source freshness. Asset-related pre-push checks require selected sources; download offloaded files in Finder before preparation. All selected sources are preflighted before conversion or pruning. Preparation records input fingerprints, source hashes and output/catalog hashes in `PreparedAssets.generated.json`.

Each pipeline captures its input snapshot before preparation and rejects receipt updates if those inputs change while it runs. Missing receipt hashes force re-encoding rather than trusting cached outputs. Receipt updates are serialized across pipelines; a failed update retains the previous receipt and requires another preparation pass.

CI and ordinary build preparation use `./Scripts/prepare-assets.sh --check --outputs-only` plus manifest/resource integrity checks. They require only committed outputs and never access the library or regenerate media. Checks revalidate artwork IDs, boss music enemies, and cinematic actor/Ultimate relationships against current content. Output checks do not prove raw-source freshness. Each project retains its own encoders, crops, gains and catalogs.

## Project generation

Project consistency and staged commit validation follow
[Verification.md](../Platform/Verification.md#generated-project-consistency).

Use `./Scripts/generate.sh` for project inputs; XcodeGen always runs uncached.

## Generation tooling

**Single entry:** `./Scripts/generate.sh` validates ContentManifest TSVs, regenerates content catalogs (trigger families are `public`; catalog blobs are `internal` and reached through `GameContent`), optionally prepares art/music/SFX/cinematics (`--assets`), then runs XcodeGen (always uncached). Pass `--skip-xcodegen` for content/asset codegen only; see [Verification.md](../Platform/Verification.md#generated-project-consistency).

| Input | Run | Review |
|---|---|---|
| Content manifests or authored catalog Swift | `./Scripts/generate.sh` | Expected catalog diff and content tests when semantics change |
| Trigger-family schema | `./Scripts/generate.sh` | Generated trigger output; authored exceptions stay authored |
| Media manifests or matching raw inputs | `./Scripts/generate.sh --assets` | Generated catalog plus expected processed files |
| `project.yml` or XcodeGen tool/wrapper inputs | `./Scripts/generate.sh` | Review authored inputs and canonical project output together |
| Content without regenerating the Xcode project | `./Scripts/generate.sh --skip-xcodegen` | Content catalog diff only |
| Media assets without regenerating the Xcode project | `./Scripts/generate.sh --assets --skip-xcodegen` | Content/media catalogs and processed files |

`Scripts/content_codegen.py` coordinates domain owners under `Scripts/internal/content/`:
abilities, items, roster (including enemies/traits), stages, Homestead, talents,
and the trigger DSL/generator. Each owner keeps its row schema, validation, and
rendering together; `common.py` derives TSV headers from row dataclasses and owns
shared resource parsing and output helpers. Manifest reads return fresh rows so
repeated validation cannot reuse stale inputs or mutated records. Stage reference-ID collectors also reread authored
encounter sources and art manifests on each validation.

Ability inventory is the slowest codegen step: the abilities owner runs the
`AbilityInventoryDump` tool (full Swift build + Xcode SDK) unless the
`.DerivedData/AbilityInventory.stamp` digest matches; force it with
`TRINKET_FORCE_ABILITY_DUMP=1` (see `assert-generated-output.sh`). Failed dump logs
are retained under `RESULTS_DIR` or `.DerivedData/ContentGeneration`, with bounded
terminal excerpts. Ability
tiers, shorthand, and the inventory regex-parse the authored catalog, and
mystery/recruit validation scrapes `Encounters/Mystery/*.swift` for `makeEvent(id:` /
`recruit(id:` — keep those call shapes stable or update the scrapes together.

Adding a new generated TSV output requires two files:
`Scripts/config/generated-paths.tsv` (committed-output gate) and the
`exclude` list in `Packages/TrinketContent/Package.swift` (keeps TSVs out of
the bundled resources).

Verification is conditional: manifest-only changes require generation plus idempotence; semantic catalog/content changes use `TrinketContentTests`; Swift source changes add the routed style check. Open only the manifest README for the input being changed.
