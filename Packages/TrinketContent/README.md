# TrinketContent

Game content catalogs — heroes, pets, enemies, abilities, items, stages, homestead nodes, and art/music/SFX references. Most content is manifest-driven (TSV → generated Swift).

## Structure

- **Content/** — Hand-written Swift for abilities that don't fit manifest patterns
- **Generated/** — Auto-generated catalogs from manifest TSVs (do not edit directly)

## Manifest sources

| Manifest | Generates |
|----------|-----------|
| `ContentManifest/abilities.tsv` | `AbilityCatalog*.generated.swift`, `AbilityShorthand.generated.swift` |
| `ContentManifest/combatants.tsv` | `GameContentRoster.generated.swift` |
| `ContentManifest/enemies.tsv` | `GameContentEnemies.generated.swift` |
| `ContentManifest/stages.tsv` | `GameContentChapters.generated.swift`, `GameContentEncounterArt.generated.swift` |
| `ContentManifest/item_bases.tsv` | `GameContentItemBases.generated.swift` |
| `ContentManifest/affixes.tsv` | `ItemAffixCatalog.generated.swift` |
| `ContentManifest/homestead_nodes.tsv` | `GameContentHomestead.generated.swift` |
| `ArtManifest/curated-assets.tsv` | `ArtCatalog.generated.swift` |
| `MusicManifest/music.tsv` | `MusicCatalog.generated.swift` |
| `SoundManifest/sfx.tsv` | `SFXCatalog.generated.swift` |

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
| `Combatant` | Hero/Pet model (stats, ability loadout) |
| `Enemy` | Enemy model |
| `ItemGenerator` | Random item generation from base + affix pools |
| `PlayerContentCatalog` | Runtime lookup for content references |
