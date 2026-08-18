# TrinketContent

Game content catalogs — heroes, companions, enemies, abilities, items, stages,
homestead nodes, talent trees, and art/music/SFX/cinematic references. Most
data content is manifest-driven (TSV → generated Swift). Abilities are authored
in Swift; talent trees are authored in `ContentManifest/talents.tsv`.

## Structure

- **Content/** — Authored Swift: abilities in `AbilityCatalog{Basic,Skill,Ultimate}.swift`. Talent lookup/config API stays in `CombatantTalentCatalog.swift`.
- **Generated/** — Auto-generated catalogs from manifests, ability shorthand, talent dictionaries, and trigger-family structs (do not edit directly)

## Manifest sources

| Manifest / source | Generates |
|----------|-----------|
| `Content/AbilityCatalog{Basic,Skill,Ultimate}.swift` | `AbilityShorthand.generated.swift`, `AbilityInventory.generated.tsv` (`id`, `name`, `tier`, `summary`), `AbilityCatalogIndex.generated.swift` |
| `Scripts/trigger_family_schema.json` | `*Triggers.generated.swift` (combat trigger family structs) |
| `ContentManifest/combatants.tsv` | `GameContentRoster.generated.swift` |
| `ContentManifest/enemies.tsv` | `GameContentEnemies.generated.swift` |
| `ContentManifest/stages.tsv` | `GameContentChapters.generated.swift`, `GameContentEncounterArt.generated.swift`, `GameContentStagesIndex.generated.swift` |
| `ContentManifest/item_bases.tsv` | `GameContentItemBases.generated.swift` |
| `ContentManifest/talents.tsv` | `CombatantTalentCatalog.generated.swift` |
| `ContentManifest/traits.tsv` | `GameContentTraits.generated.swift` |
| `ContentManifest/affixes.tsv` | `ItemAffixCatalog.generated.swift` |
| `ContentManifest/homestead_nodes.tsv` | `GameContentHomestead.generated.swift` |
| `ArtManifest/curated-assets.tsv` | `ArtCatalog.generated.swift` |
| `MusicManifest/music.tsv` | `MusicCatalog.generated.swift` |
| `SoundManifest/sfx.tsv` | `SFXCatalog.generated.swift` + `Trinket/Media/SFX` |
| `CinematicManifest/cinematics.tsv` | `UltimateCinematicCatalog.generated.swift` + `Trinket/Media/Cinematics` |

## Adding content

```sh
# Edit the relevant TSV, then:
./Scripts/generate.sh
./Scripts/build.sh
```

See `ContentManifest/README.md` for TSV format details. Generated files are committed so the app builds without rerunning the generator.

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
