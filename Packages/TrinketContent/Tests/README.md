# TrinketContent Tests

Test ownership for `Packages/TrinketContent/Tests/TrinketContentTests/`.

| Concern | Owner | Notes |
|---------|-------|-------|
| Ability catalog invariants | `AbilityCatalogTests` | IDs, validator, DoT pairing, builder smoke |
| Ultimate cinematic catalog | `UltimateCinematicCatalogTests` | Actor-scoped resolve + fallback |
| Art catalog cross-references | `ArtCatalogIntegrationTests` | Manifest IDs resolve to expected content owners |
| Combatant catalog graph | `CombatantCatalogTests` | Hero/companion loadouts, health/mana |
| Homestead node catalog | `HomesteadCatalogTests` | Node IDs, tiers, unlock graph, tier effects |
| Contracts | `ContractsTests` | Offer identity per enemy |
| Content access policy | `ContentAccessPolicyTests` | Free/full chapter/labyrinth/spire gates |
| Legacy ID remap | `LegacyIDRemapInvariantTests` | Talent/ability remap targets resolve |
| Unique catalog | `UniqueCatalogTests` | Counts, slots, pinned powers, save decode |
| Combatant talent trees | `CombatantTalentCatalogTests` | Three trees with at least seven nodes each, affinities, authored IDs, no placeholders |
| Trigger family schema | `Scripts/content_codegen_triggers.py` + `Scripts/trigger_family_schema.json` | Generated `*Triggers` fields must match the schema; generation fails on drift |
| Catalog cross-invariants | `GameContentCatalogInvariantTests` | Cross-catalog ID and wiring checks |
| Enemy traits | `GameContentTraitCatalogTests` | Enemy→trait ID refs and non-empty trait copy |
| Enemy balance classification | `EnemyCatalogTests` | Normal/boss bands, kits, HP bands |
| Loadout selection | `AbilityLoadoutTests` | Tier unlock filtering, `AbilityChoices` fallback |
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
(`Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift`).
