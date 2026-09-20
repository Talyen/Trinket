# Content and manifest context

Read the shared safeguards and the section for the changed input. Column formats
live in each manifest directory's README; open only the relevant one.

## Shared safeguards

Edit authored inputs (manifests, ability Swift, `ContentManifest/talents.tsv`, or the relevant `Scripts/internal/content/trigger_families/*.json`). Do not hand-edit generated Swift, generated inventory TSV, processed assets/resources, or the Xcode project. The verification router owns generation and idempotence.

Catalog inputs and generated outputs must stay in sync. Review generated changes
against authored inputs; generation must be idempotent. Generated files are committed
so the app builds without rerunning generation. Local handoff proves idempotence;
pre-push and CI check committed-output completeness against HEAD.

The router owns verification selection. Manifest-only changes require generation
and idempotence; semantic content changes use content tests; Swift adds style checks.
Commit staging follows [Release](../Platform/Release.md#local-hooks-and-push-discipline).

## Abilities

**Abilities:** author only in the authored catalog Swift under `Packages/TrinketContent/Sources/TrinketContent/Abilities/`. To list or understand abilities, use `AbilityCatalog.all` or the generated inventory; there is no authored abilities TSV.

Ability declarations and ordered tier lists live in `AbilityCatalog+Basic.swift`,
`AbilityCatalog+Skill.swift`, and `AbilityCatalog+Ultimate.swift`. The catalog facade
combines those lists; preserve their order and existing IDs. Use
`python3 Scripts/content-inspect.py --kind abilities --id <id>` for the authored location.

## Manifests

**Talents:** author in `ContentManifest/talents.tsv` using the affix trigger/modifier DSL. Keep lookup/config in `CombatantTalentCatalog.swift`; generated dictionaries are outputs. See `ContentManifest/README.md`.

**Enemy traits:** author in `ContentManifest/traits.tsv` (same DSL); generated catalogs are outputs.

For exact manifest inspection, use `python3 Scripts/content-inspect.py --id <id>`;
`--trigger <canonicalField>` finds entries using that trigger through the same DSL
parser as generation. Results identify authored locations and disclose omitted
records/shortened fields; follow pagination or `--full` to expand. `--references`
adds bounded literal source/test hints, not a semantic consumer graph.

## Trigger schemas

Trigger definitions live one family per JSON under `Scripts/internal/content/trigger_families/`;
`index.json` preserves generation order. Edit the relevant family, not the index,
for a field change. `Scripts/internal/content/modifiers.json` owns modifier DSL
names, Swift cases, numeric kinds and keyword arguments. It generates the
`AffixModifier` enum and mechanical transforms; gameplay application, presentation,
and magnitude bump policy remain authored. Preserve case names, associated-value
shapes, and Codable representations when evolving these definitions.

Trigger fields used by affixes require `affix_roll` metadata in their family JSON:
`{"kind": "int" | "percent", "order": N}` for rollable values, or
`{"reason": "..."}` for deliberate exclusions. Orders are unique and nonnegative;
preserve existing orders and append new rollable fields so seeded roll/bump
selection stays stable. Generation owns the typed field list and exclusion reasons;
rolling behavior, numeric text replacement, and gameplay remain authored.

## Media assets

Shared media-pipeline rules: raw source folders (`Raw Assets/` and per-pipeline
raw directories) are not in Xcode target membership; processed outputs under
`Trinket/` are. Hash-based media pipelines re-encode when source bytes or encode settings
change; set `FORCE_ASSET_REENCODE=1` to rebuild regardless of cached state.

Each `prepare-<media>-assets.sh` is that pipeline's focused debugging entry point.
Use `./Scripts/generate.sh --assets` for media inputs.

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
rendering together; `common.py` owns shared TSV and output helpers.

Ability inventory is the slowest codegen step: the abilities owner runs the
`AbilityInventoryDump` tool (full Swift build + Xcode SDK) unless the
`.DerivedData/AbilityInventory.stamp` digest matches; force it with
`TRINKET_FORCE_ABILITY_DUMP=1` (see `assert-generated-output.sh`). Failed dump logs
are retained under `RESULTS_DIR` or `.DerivedData/ContentGeneration`, with bounded
terminal excerpts. Ability
tiers, shorthand, and the inventory regex-parse the authored catalog, and
mystery/recruit validation scrapes `Encounters/*.swift` for `makeEvent(id:` /
`recruit(id:` — keep those call shapes stable or update the scrapes together.

Adding a new generated TSV output requires two files:
`Scripts/config/generated-paths.tsv` (committed-output gate) and the
`exclude` list in `Packages/TrinketContent/Package.swift` (keeps TSVs out of
the bundled resources).

Verification is conditional: manifest-only changes require generation plus idempotence; semantic catalog/content changes use `TrinketContentTests`; Swift source changes add the routed style check. Open only the manifest README for the input being changed.
