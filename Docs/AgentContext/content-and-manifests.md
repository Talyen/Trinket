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
Actor-targeted damage components pay Health costs and contribute no damage keyword
to gameplay or identity, including alternative outcomes. Presentation still derives
their Health keyword from the summary.
Multi-hit direct-damage totals saturate, including after Mana empowerment.

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
Generation derives `CombatTriggerField` identities and one root field registry from
the same schema. Its typed descriptors address family storage directly and share
flat save keys, neutral defaults, and type-compatible merge policies across decoding,
sparse encoding, populated-field traversal, and equipment stacking. Families own gameplay
values and initialize through typed configuration closures (for example,
`BlockTriggers { $0.blockPerTurn = 2 }`). Stored-property defaults are the sole
initialization defaults; there is no parallel per-field constructor parameter list.
The root registry owns merging, entering copy-on-write storage once per merge.
`CombatTriggerField` also supplies the Codable keys, including unknown-key tolerance.
Root dynamic-member mutations pass through the same copy-on-write storage. Combat provenance and affix-roll policy use those typed identities;
raw names remain the flat Codable keys. Renaming a field requires migrating its
compiled consumers while preserving or migrating the stored key.
Validation checks Swift identifiers, typed defaults, type-compatible merge operations,
and 64-bit `Int` bounds before rendering trigger/modifier literals.
Fields omit conventional `default`/`merge` pairs: `Int` and `Double` use `0`/`add`,
`Bool` uses `false`/`or`, `Keyword?` uses `nil`/`coalesce`, and `[Int]` uses
`[]`/`union`. Integer additions saturate when saved powers combine. The loader
expands these before validation and generation. Keep
exceptions explicit, including multiplier defaults of `1` and `max` merge rules;
changing a convention changes combat and flat save decoding for every omitted field.

Trigger fields used by affixes require `affix_roll` metadata in their family JSON:
`{"kind": "int" | "percent", "order": N}` for rollable values, or
`{"reason": "..."}` for deliberate exclusions. Orders are unique and nonnegative;
preserve existing orders and append new rollable fields so seeded roll/bump
selection stays stable. Generation owns the typed field list and exclusion reasons;
rolling behavior, numeric text replacement, and gameplay remain authored.
`InventoryItem` normalizes saved Spitebloom, Ashen Wake, Cauterize, Toxic Remedy,
Beacon, Infected, Toxic Incense, and Heartshock powers before scaling, perfect-roll
inspection, and corruption. Keep legacy serialized fields for decoding, preserve
their rolled magnitude, and clear
retired proc fields in the effective power. Beacon doubles its old healing roll
once when converting to its first-Holy-attack-per-turn rule. Toxic Remedy describes
the effective healing fraction after equipment scaling.

Affix scaling, rolling, and corruption share the ordered magnitude traversal in
`ItemAffixPower+Rolling.swift`. Bind description numbers against the original text,
including unchanged fields, so equal magnitudes and replacement collisions retain
their field ownership. Percentage rolls retain an oversized original magnitude
when its integer-point conversion or choice pool cannot be bounded safely; normal
catalog roll grids stay unchanged. Corruption availability and candidate selection share one
lazy eligibility filter. Preserve this order and the existing numeric/save formats.

## Media assets

Art references derive thumbnail names with the `_thumb` suffix; full-only resource
and slot-background references expose only the full image. Catalog kind metadata
in `Scripts/prepare-media.py` owns reference types and crop fields;
`asset-library.py` owns encode settings shared by conversion and input fingerprints.
The focused shell commands delegate to that shared incremental pipeline. It reuses
`asset-library.py` for source identity and receipts; static Swift catalog declarations
live in `Scripts/internal/media_templates/`.

Shared media-pipeline rules: raw source folders in the external Asset Library are not in Xcode target membership; processed outputs under
`Trinket/` are. Hash-based media pipelines re-encode when source bytes or encode settings
change; set `FORCE_ASSET_REENCODE=1` to rebuild regardless of cached state.

Each `prepare-<media>-assets.sh` is that pipeline's focused debugging entry point.
Use `./Scripts/prepare-assets.sh` (or `generate.sh --assets`) locally for media inputs. Both games default to `~/Documents/Asset Library`; override with `ASSET_LIBRARY_ROOT`. Source paths in manifests are library-relative. Artwork lives under shared Characters, Actions, Items, Places, Interface, Animation, and Branding folders. Subject folders group portrait/landscape and facing variants; the manifest selects the exact master. Game names remain in intrinsically branded filenames, not ownership folders. Adding unselected library files cannot change shipping inventories; new revisions use distinct filenames and explicit manifest adoption. App-icon sources are selected in `ArtManifest/app-icon.tsv`.

`./Scripts/prepare-assets.sh --check` verifies local source freshness. Asset-related pre-push checks require selected sources; download offloaded files in Finder before preparation. All selected sources are preflighted before conversion or pruning. Preparation records input fingerprints, source hashes and output/catalog hashes in `PreparedAssets.generated.json`.

Each pipeline captures its input snapshot before preparation and rejects receipt updates if those inputs change while it runs. Missing receipt hashes force re-encoding rather than trusting cached outputs. Receipt updates are serialized across pipelines and retain only active asset kinds; a failed update retains the previous receipt and requires another preparation pass.

Local preparation automatically repairs missing library-relative paths using the last prepared source hashes. Normal local build preparation also relinks and prepares relocated sources when the library is available, without a separate repair request. It updates authored manifests only for a unique byte-identical match; Icon Composer packages must match the complete recorded package, including internal paths. Existing paths are left alone. Unrecorded, changed, or ambiguous sources require explicit selection and stop preparation before conversion. Relinking searches the library only when selected paths are missing; symlinks are not recovery candidates. Use the [relink commands](../../Scripts/Reference.md#assets) to preview or apply repairs separately. Read-only checks and source-free CI never relink.

CI uses `./Scripts/prepare-assets.sh --check --outputs-only` plus manifest/resource integrity checks. It requires only committed outputs and never accesses the library or regenerates media. Ordinary local build preparation performs the same output check after automatic relocation recovery; without a local library it uses committed outputs alone. Checks revalidate artwork IDs and boss music enemies against current content. Output checks do not prove raw-source freshness. Each project retains its own encoders, crops, gains and catalogs.

## Project generation

Project consistency and staged commit validation follow
[Verification.md](../Platform/Verification.md#generated-project-consistency).

Use `./Scripts/generate.sh` for project inputs; XcodeGen always runs uncached.

## Generation tooling

**Single entry:** `./Scripts/generate.sh` validates ContentManifest TSVs, regenerates content catalogs (trigger families are `public`; catalog blobs are `internal` and reached through `GameContent`), optionally prepares art/music/SFX (`--assets`), then runs XcodeGen (always uncached). Pass `--skip-xcodegen` for content/asset codegen only; see [Verification.md](../Platform/Verification.md#generated-project-consistency).

Local build preparation tracks both generation inputs and registered content/project
outputs, including shared Xcode schemes, so missing or changed outputs trigger repair.
Prepared media is checked against its receipt on every preparation.

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
