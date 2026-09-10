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

## Combat trigger value semantics

`CombatTraitTriggers` owns private copy-on-write storage. Its field payload uses
checked `Sendable` conformance, and all field mutations pass through one accessor
that ensures unique storage before writing. The wrapper's unchecked conformance
relies on this encapsulation; storage references must never escape the wrapper.

## Random item rewards

`ItemRewardGenerator` owns category selection and candidate filtering for battles,
shops, and Mysteries. Tune the level anchors and profile multipliers in
`Sources/TrinketContent/ItemLootPolicy.swift`. Weights interpolate linearly and clamp
outside the anchors. Bosses triple premium weights; Moonlit Sanctum multiplies
Astral weight by `1 + bonus/100`. After ownership, reservations, keywords, and
explicit pools remove unavailable categories, the remaining weights normalize.
There are no category-conversion fallbacks. Guaranteed Astral rewards constrain
the same resolver to Astral gear; exact authored item rewards remain exact.

Item reward level uses authored Journey progression (chapter base for shops and
Mysteries), Spire floor level, Labyrinth depth, or resolved Contract level.
Party-adjusted currency and experience calculations remain separate. Saved items
and pinned offers retain their contents; newly generated rewards use current tuning.

From the repository root, produce the exact balance report with:

```sh
swift run --package-path Packages/TrinketContent LootBalanceReport
```

The report covers levels 1–20, both profiles, all Sanctum bonuses, category
exhaustion, shops, and guaranteed Astral rewards. Its cumulative chances assume
unchanged inputs and pool availability across the displayed reward count.
