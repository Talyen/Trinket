# TrinketContent

Game content catalogs — heroes, companions, enemies, abilities, items, stages,
homestead nodes, talent trees, and art/music/SFX/cinematic references. Most
data content is manifest-driven (TSV → generated Swift). Abilities are authored
in Swift; talent trees are authored in `ContentManifest/talents.tsv`.

## Structure

- **Content/** — Authored Swift: abilities in `AbilityCatalog{Basic,Skill,Ultimate}.swift`. Talent lookup/config API stays in `CombatantTalentCatalog.swift`.
- **Generated/** — Auto-generated catalogs from manifests, ability shorthand, talent dictionaries, and trigger-family structs (do not edit directly)

## Manifest sources

Schemas and input/output ownership live in
[`ContentManifest/README.md`](../../ContentManifest/README.md) and the matching
media-manifest READMEs. `Generated/` is the output of `./Scripts/generate.sh`;
do not maintain a second generated-file inventory here. Abilities remain
authored in `Content/AbilityCatalog{Basic,Skill,Ultimate}.swift`; trigger-family
schema remains in `Scripts/trigger_family_schema.json`.

## Adding content

```sh
# Edit the relevant TSV, then:
./Scripts/generate.sh
./Scripts/build.sh
```

Generated files are committed so the app builds without rerunning the generator.

## Key types

| Type | Role |
|------|------|
| `GameContent` | Central registry for all game content |
| `Ability` / `TargetedEffect` | Ability model with effect declarations |
| `Combatant` | Hero/Companion model (stats, ability loadout) |
| `Enemy` | Enemy model |
| `ItemGenerator` | Random item generation from base + affix pools |
| `ShopOfferGenerator` | Procedural Merchant's Shop shelves (rarity + gold prices) |
| `PlayerContentCatalog` | Runtime lookup for content references |
