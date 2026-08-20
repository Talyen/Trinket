# Content and manifest context

Use for abilities, item bases, stages, art, music, SFX, cinematics, and project generation.

**Single entry:** `./Scripts/generate.sh` validates ContentManifest TSVs, regenerates content catalogs (emits `public` from `content_codegen.py`), optionally prepares art/music/SFX/cinematics (`--assets`), then runs XcodeGen.

| Input | Run | Review |
|---|---|---|
| `ContentManifest/` or custom source in `TrinketContent/Content/` | `./Scripts/generate.sh` | Expected catalog diff |
| `Scripts/trigger_family_schema.json` | `./Scripts/generate.sh` | `Generated/*Triggers.generated.swift` (`CombatTraitTriggers` box stays authored) |
| `ArtManifest/`, `MusicManifest/`, `SoundManifest/`, `CinematicManifest/`, or matching raw inputs | `./Scripts/generate.sh --assets` | Generated catalog plus expected processed files |
| `project.yml` | `./Scripts/generate.sh` | Regenerated project diff |

After content edits, stage `Packages/TrinketContent/Sources/TrinketContent/Generated/`. Pipeline formats live in each manifest directory's README.

**Abilities:** author only in `Packages/TrinketContent/Sources/TrinketContent/Content/AbilityCatalog{Basic,Skill,Ultimate}.swift`. To list or understand all abilities, read `Generated/AbilityInventory.generated.tsv` (`id`, `name`, `tier`, `summary` from `Ability.summary`) or use `AbilityCatalog.all` — there is no authored abilities TSV.

**Talents:** author in `ContentManifest/talents.tsv` using the affix trigger/modifier DSL. Keep lookup/config in `CombatantTalentCatalog.swift`. Tree names stay in `combatantTreeAffinities`. Generated dictionaries: `Generated/CombatantTalentCatalog.generated.swift` (gated in `assert-generated-output.sh`). See `ContentManifest/README.md`.

**Enemy traits:** author in `ContentManifest/traits.tsv` (same DSL). Generates `GameContentTraits.generated.swift`.

Edit authored inputs (manifests, ability Swift, `ContentManifest/talents.tsv`, or `Scripts/trigger_family_schema.json`). Do not hand-edit generated Swift, generated inventory TSV, processed assets/resources, or the Xcode project. The verification router owns generation and idempotence; regenerate must be a no-op, and before push/CI the default assert checks generated paths match HEAD. Stage only outputs caused by the changed input.

Verification is conditional: manifest-only changes require generation plus idempotence; semantic catalog/content changes use `TrinketContentTests`; Swift source changes add the routed style check. Pipeline formats live in each manifest directory's README; open only the one you are changing.
