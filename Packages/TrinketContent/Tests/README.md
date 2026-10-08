# TrinketContent Tests

Test ownership for `Packages/TrinketContent/Tests/TrinketContentTests/`.
Tests follow the content domains in `Abilities/`, `Equipment/`, `Encounters/`,
`Roster/`, `Homestead/`, and `Media/`; cross-domain invariants stay at the root.

| Concern | Owner | Notes |
|---------|-------|-------|
| Ability catalog and descriptions | `AbilityCatalogTests` | IDs, authored operations, and player-facing card text |
| Ability validation | `AbilityValidationTests` | Base, random, and conditional paths; target rules, tier damage, and description overrides |
| Art catalog cross-references | `ArtCatalogIntegrationTests` | Ability/item/stage wiring and artwork for every player combatant and enemy |
| Combatant catalog graph | `CombatantCatalogTests` | Hero/companion loadouts, health/mana |
| Homestead node catalog | `HomesteadCatalogTests` | Node IDs, tiers, unlock graph, tier effects |
| Contracts | `ContractGeneratorTests` | Exclusions, exhausted-pool fallback, saved offers, and independent identities for repeated targets |
| Voyage | `VoyageTests` | Regional route generation, chapter keyword affinity, and completion-bonus rounding/saturation |
| Content access policy | `ContentAccessPolicyTests` | Free/full chapter/labyrinth/spire gates |
| Unique catalog | `UniqueCatalogTests` | Counts, slots, pinned powers, save decode |
| Combatant talent trees | `CombatantTalentCatalogTests` | Three trees with at least seven nodes each, affinities, authored IDs, no placeholders |
| Trigger family schema | `Scripts/internal/content/content_codegen_triggers.py` + `Scripts/internal/content/trigger_families/index.json` | Generated `*Triggers` fields must match the schema; generation fails on drift |
| Catalog cross-invariants | `GameContentCatalogInvariantTests` | Authored encounter ID uniqueness and stage wiring; manifest ID validation stays in codegen |
| Affix modifier compatibility | `AffixModifierTests` | Saved representations and minimum bump boundaries; transformations are exercised by `ItemAffixRollCoverageTests` |
| Enemy traits | `GameContentTraitCatalogTests` | Enemy→trait ID refs and boss resistance rules; `KeywordCohesionTests` checks mechanic descriptions |
| Enemy kits and Health | `EnemyCatalogTests` | Normal HP band, complete kits, canonical ability references; Journey/Spire tests own boss placement |
| Loadout selection | `AbilityLoadoutTests` | Tier ordering, canonical selection/fallback, preserved empty tiers |
| Item generation | `ItemGeneratorTests`, `ThemedGearGeneratorTests` | Seeded RNG, affix counts |
| Item affix magnitude rolls | `ItemAffixMagnitudeRollTests` | Seeded magnitude ranges |
| Shop offers | `ShopOfferGeneratorTests` | Offer count, price/rarity rules, seed stability |
| Item affix catalog | `ItemAffixCatalogTests` | Weights, slot pools |
| Combatant equipment rules | `CombatantEquipmentTests` | Hero vs companion slots |
| Encounter level scaling | `EncounterLevelResolverTests` | Chapter span, contract offsets |
| Journey catalog | `JourneyCatalogTests` | Chapter/stage wiring |
| Labyrinth catalog | `LabyrinthCatalogTests` | Layout diversity, node types |
| Mystery events | `MysteryEventCatalogTests` | Event IDs, effect coverage |
| Corruption altar picks | `CorruptionAltarPickTests` | Eligible-item selection |
| Spire catalog | `SpireCatalogTests` | Spire identities and encounter wiring |

**Not here:** Encounter art presentation wiring
(`Packages/TrinketFeatureSupport/Tests/TrinketFeatureSupportTests/StageMapPresentationTests.swift`)
or `PlayerRosterState` battle-config logic
(`Packages/TrinketPersistence/Tests/TrinketPersistenceTests/Inventory/PlayerRosterStateTests.swift`).
