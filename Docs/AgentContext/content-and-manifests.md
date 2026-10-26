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
Generated English descriptions use the same typed rule renderer as localized
summaries, with an explicit English locale and without applying authored overrides.
Damage-component and targeted-effect projections are derived once per immutable
definition and shared by repeated reads; ordered operations remain authoritative.
Keep caches outside value equality/hashing; transformations must receive fresh storage
so empowered or resolved cards cannot reuse the original card's text or keywords.
Actor-targeted damage components pay Health costs and contribute no damage keyword
to gameplay or identity, including alternative outcomes. Presentation still derives
their Health keyword from the summary.
Multi-hit direct-damage totals saturate, including after Mana empowerment.

`AbilityValidationTests` checks every base, random-branch, and conditional operation:
Cleansing (including Panacea) targets allies, while Purge targets enemies. It also
rejects redundant description overrides. Catalog tests protect identity and shared
rule visibility; engine tests own combat behavior. Avoid per-ability snapshots of
authored numbers or copy, damage-tier heuristics, and ID allowlists that turn balance
or wording edits into parallel test maintenance.

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
`index.json` preserves generation order; filenames identify families. Edit the relevant family, not the index,
for a field change. `Scripts/internal/content/modifiers.json` owns modifier DSL
names, Swift cases, numeric kinds and keyword arguments. It generates the
`AffixModifier` enum and mechanical transforms; gameplay application, presentation,
and magnitude bump policy remain authored. Preserve case names, associated-value
shapes, and Codable representations when evolving these definitions.
Generation derives `CombatTriggerField` identities and one root field registry from
the same schema. Its typed descriptors address one flat value payload and share
flat save keys, neutral defaults, and type-compatible merge policies across decoding,
sparse encoding, populated-field traversal, and equipment stacking. Construct values
with `CombatTraitTriggers { $0.blockPerTurn = 2 }`; families organize schema authoring
without separate Swift wrapper types. Stored-property defaults own initialization.
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
selection stays stable. Affix rows may provide `basic_roll_ranges` and
`astral_roll_ranges` for exact per-field bounds; omitted bounds preserve existing
rolling. `ItemAffixPower` stores optional bounds alongside its saved magnitude,
defaulting to none for earlier saves. Generation owns the typed field list and exclusion reasons;
rolling behavior, numeric text replacement, and gameplay remain authored.
Compatibility transforms preserve saved roll bounds alongside unchanged magnitudes,
including when only description formatting or another trigger changes.
`InventoryItem` normalizes saved Spitebloom, Ashen Wake, Cauterize, Toxic Remedy,
Beacon, Infected, Toxic Incense, Heartshock, Whiplash, and Denouncing powers before
scaling, perfect-roll inspection, and corruption. Keep legacy serialized fields for decoding, preserve
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

Shared media-pipeline rules: selected raw masters are tracked in repository `AssetSources/`, outside Xcode target membership; processed outputs under
`Trinket/` are. Hash-based media pipelines re-encode when source bytes or encode settings
change; set `FORCE_ASSET_REENCODE=1` to rebuild regardless of cached state.

Each `prepare-<media>-assets.sh` is that pipeline's focused debugging entry point.
Use `./Scripts/prepare-assets.sh` (or `generate.sh --assets`) locally for media inputs. Source paths in manifests are relative to repository `AssetSources/`; external library paths and `ASSET_LIBRARY_ROOT` overrides are not used. Selected artwork lives under `AssetSources/2d Assets/Game Sources/`; selected audio lives under `AssetSources/Sounds/Game Sources/`. Subject folders group portrait/landscape and facing variants; the manifest selects the exact master. Game names remain in intrinsically branded filenames, not ownership folders. New or revised assets must be copied into the repository and explicitly adopted; no shared-library updates are imported automatically. App-icon sources are selected in `ArtManifest/app-icon.tsv`.

`./Scripts/prepare-assets.sh --check` verifies repository source freshness. Asset-related pre-push checks require the tracked selected masters; restore `AssetSources/` if using a sparse checkout. All selected sources are preflighted before conversion or pruning. Preparation records input fingerprints, source hashes and output/catalog hashes in `PreparedAssets.generated.json`.

Each pipeline captures its input snapshot before preparation and rejects receipt updates if those inputs change while it runs. Missing receipt hashes force re-encoding rather than trusting cached outputs. Receipt updates are serialized across pipelines and retain only active asset kinds; a failed update retains the previous receipt and requires another preparation pass.

Builds, checks, and ordinary media preparation never relink sources or rewrite authored selections. Missing masters stop preparation before conversion or pruning. After intentionally moving repo-local masters, update their manifests or explicitly use the [relink commands](../../Scripts/Reference.md#assets). These search only `AssetSources/`, using the last prepared source hashes, and apply only unique byte-identical matches. Icon Composer packages must match the complete recorded package, including internal paths; symlinks are not recovery candidates. `prepare-assets.sh --heal` remains an explicit local relink-and-prepare command, including retries after interrupted preparation.

CI uses `./Scripts/prepare-assets.sh --check --outputs-only` plus manifest/resource integrity checks. It requires only committed outputs and never regenerates media; sparse build jobs can omit `AssetSources/`. Ordinary local build preparation performs the same output check without discovering or repairing source masters. Checks revalidate artwork IDs and boss music enemies against current content. Output checks do not prove raw-source freshness. Each project retains its own encoders, crops, gains and catalogs.

For code-only working copies, selected masters can remain in Git without being materialized:

```sh
git sparse-checkout set --no-cone '/*' '!/AssetSources/'
```

Use this only in a clean checkout without unique or active authoring work under `AssetSources/`. Sparse settings belong to this working copy; other worktrees may retain their masters. Missing skipped masters are intentional, not deleted assets. App resources stay materialized, and ordinary builds and output-only checks need no Drive connection. Before media preparation, source-freshness checks, or asset-related pre-push checks, run `git sparse-checkout disable` to restore the full authoring checkout from Git. Check local headroom first; restoring masters costs their full working-copy size. Never force sparse removal over changes or replace the repository sources with a required mounted Drive path. This changes working-copy residency, not Git history or object storage.

## Project generation

Project consistency and staged commit validation follow
[Verification.md](../Platform/Verification.md#generated-project-consistency).

Use `./Scripts/generate.sh` for project inputs; XcodeGen always runs uncached.

## Generation tooling

**Single entry:** `./Scripts/generate.sh` validates ContentManifest TSVs, regenerates content catalogs (the trigger model is `public`; catalog blobs are `internal` and reached through `GameContent`), optionally prepares art/music/SFX (`--assets`), then runs XcodeGen (always uncached). Pass `--skip-xcodegen` for content/asset codegen only; see [Verification.md](../Platform/Verification.md#generated-project-consistency).

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
