# TrinketContent Tests

Test ownership for `Packages/TrinketContent/Tests/TrinketContentTests/`.

| Concern | Owner | Notes |
|---------|-------|-------|
| Ability catalog invariants | `AbilityCatalogTests` | IDs, validator, DoT pairing, builder smoke |
| Ultimate cinematic catalog | `UltimateCinematicCatalogTests` | Actor-scoped resolve + fallback |
| Art catalog cross-references | `ArtCatalogIntegrationTests` | Manifest IDs resolve to expected content owners |
| Ability prose examples | `AbilityDescriptionFormatterTests` | Focused examples only; no full-catalog loop |
| Combatant / homestead graph | `CombatantCatalogTests` | ID uniqueness, stage→enemy links, hero/companion loadouts |
| Enemy balance classification | `EnemyCatalogTests` | Normal/boss bands, kits, HP bands |
| Loadout selection | `AbilityLoadoutTests` | Tier unlock filtering, `AbilityChoices` fallback |
| Item generation | `ItemGeneratorTests`, `ThemedGearGeneratorTests` | Seeded RNG, affix counts |
| Shop offers | `ShopOfferGeneratorTests` | Offer count, price/rarity rules, seed stability |
| Item affix catalog | `ItemAffixCatalogTests` | Weights, slot pools |
| Combatant equipment rules | `CombatantEquipmentTests` | Hero vs companion slots |
| Encounter level scaling | `EncounterLevelResolverTests` | Chapter span |

**Not here:** Encounter art presentation wiring
(`Packages/TrinketFeatureSupport/Tests/TrinketFeatureSupportTests/StageMapPresentationTests.swift`)
or `PlayerRosterState` battle-config logic
(`Packages/TrinketPersistence/Tests/TrinketPersistenceTests/PlayerRosterStateTests.swift`).
