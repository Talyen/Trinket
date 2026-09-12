# Content and manifest context

Use for abilities, item bases, stages, art, music, SFX, cinematics, and project generation.

This card owns the workflow. Column formats live in each manifest directory's
README; open only the manifest README for the input being changed.

**Single entry:** `./Scripts/generate.sh` validates ContentManifest TSVs, regenerates content catalogs (trigger families are `public`; catalog blobs are `internal` and reached through `GameContent`), optionally prepares art/music/SFX/cinematics (`--assets`), then runs XcodeGen. Pass `--skip-xcodegen` for content/asset codegen only.

| Input | Run | Review |
|---|---|---|
| Content manifests or authored catalog Swift | `./Scripts/generate.sh` | Expected catalog diff and content tests when semantics change |
| Trigger-family schema | `./Scripts/generate.sh` | Generated trigger output; authored exceptions stay authored |
| Media manifests or matching raw inputs | `./Scripts/generate.sh --assets` | Generated catalog plus expected processed files |
| `project.yml` or XcodeGen tool/wrapper inputs | `./Scripts/generate.sh` | Review authored inputs and canonical project output together |
| Content/assets without regenerating the Xcode project | `./Scripts/generate.sh --skip-xcodegen` | Catalog/asset diff only |

Project consistency and staged commit validation follow
[Verification.md](../Platform/Verification.md#generated-project-consistency).

Review generated changes against their authored inputs. When a commit is requested,
follow [Release](../Platform/Release.md#local-hooks-and-push-discipline) for staging
only the relevant inputs and outputs. Each `prepare-<media>-assets.sh` is that
pipeline's focused debugging entry point.

Shared media-pipeline rules: raw source folders (`Raw Assets/` and per-pipeline
raw directories) are not in Xcode target membership; processed outputs under
`Trinket/` are. Generated files are committed so the app builds without rerunning
the generator. Local handoff checks that a second generation leaves outputs
unchanged; pre-push and CI check committed-output completeness against HEAD.
Hash-based media pipelines re-encode when source bytes or encode settings
change; set `FORCE_ASSET_REENCODE=1` to rebuild regardless of cached state.

**Abilities:** author only in the authored catalog Swift under `Packages/TrinketContent/Sources/TrinketContent/Abilities/`. To list or understand abilities, use `AbilityCatalog.all` or the generated inventory; there is no authored abilities TSV.

**Talents:** author in `ContentManifest/talents.tsv` using the affix trigger/modifier DSL. Keep lookup/config in `CombatantTalentCatalog.swift`; generated dictionaries are outputs. See `ContentManifest/README.md`.

**Enemy traits:** author in `ContentManifest/traits.tsv` (same DSL); generated catalogs are outputs.

Edit authored inputs (manifests, ability Swift, `ContentManifest/talents.tsv`, or `Scripts/internal/content/trigger_family_schema.json`). Do not hand-edit generated Swift, generated inventory TSV, processed assets/resources, or the Xcode project. The verification router owns generation and idempotence.

Verification is conditional: manifest-only changes require generation plus idempotence; semantic catalog/content changes use `TrinketContentTests`; Swift source changes add the routed style check. Open only the manifest README for the input being changed.
