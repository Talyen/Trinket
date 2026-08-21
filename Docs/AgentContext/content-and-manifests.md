# Content and manifest context

Use for abilities, item bases, stages, art, music, SFX, cinematics, and project generation.

**Single entry:** `./Scripts/generate.sh` validates ContentManifest TSVs, regenerates content catalogs (emits `public` from `content_codegen.py`), optionally prepares art/music/SFX/cinematics (`--assets`), then runs XcodeGen.

| Input | Run | Review |
|---|---|---|
| Content manifests or authored catalog Swift | `./Scripts/generate.sh` | Expected catalog diff and content tests when semantics change |
| Trigger-family schema | `./Scripts/generate.sh` | Generated trigger output; authored exceptions stay authored |
| Media manifests or matching raw inputs | `./Scripts/generate.sh --assets` | Generated catalog plus expected processed files |
| `project.yml` | `./Scripts/generate.sh` | Regenerated project diff |

After content edits, stage `Packages/TrinketContent/Sources/TrinketContent/Generated/`. Pipeline formats live in each manifest directory's README; each `prepare-<media>-assets.sh` is that pipeline's focused debugging entry point.

**Abilities:** author only in the authored catalog Swift under `Packages/TrinketContent/Sources/TrinketContent/Content/`. To list or understand abilities, use `AbilityCatalog.all` or the generated inventory; there is no authored abilities TSV.

**Talents:** author in `ContentManifest/talents.tsv` using the affix trigger/modifier DSL. Keep lookup/config in `CombatantTalentCatalog.swift`; generated dictionaries are outputs. See `ContentManifest/README.md`.

**Enemy traits:** author in `ContentManifest/traits.tsv` (same DSL); generated catalogs are outputs.

Edit authored inputs (manifests, ability Swift, `ContentManifest/talents.tsv`, or `Scripts/trigger_family_schema.json`). Do not hand-edit generated Swift, generated inventory TSV, processed assets/resources, or the Xcode project. The verification router owns generation and idempotence; regenerate must be a no-op, and before push/CI the default assert checks generated paths match HEAD. Stage only outputs caused by the changed input.

Verification is conditional: manifest-only changes require generation plus idempotence; semantic catalog/content changes use `TrinketContentTests`; Swift source changes add the routed style check. Open only the manifest README for the input being changed.
