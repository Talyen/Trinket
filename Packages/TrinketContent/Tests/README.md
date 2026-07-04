# TrinketContent Tests

Test ownership for `Packages/TrinketContent/Tests/TrinketContentTests/`.

| Concern | Owner | Notes |
|---------|-------|-------|
| Ability catalog invariants | `AbilityCatalogTests` | IDs, validator, DoT pairing, builder smoke |
| Ability prose examples | `AbilityDescriptionFormatterTests` | Focused examples only; no full-catalog loop |
| Combatant / homestead graph | `CombatantCatalogTests` | ID uniqueness, stage→enemy links, hero/pet loadouts |
| Enemy balance classification | `EnemyCatalogTests` | Boss/elite bands, kits, HP bands |
| Loadout selection | `AbilityLoadoutTests` | Tier unlock filtering, `AbilityChoices` fallback |
| Item generation | `ItemGeneratorTests`, `ThemedGearGeneratorTests` | Seeded RNG, affix counts |
| Item affix catalog | `ItemAffixCatalogTests` | Weights, slot pools |
| Combatant equipment rules | `CombatantEquipmentTests` | Hero vs pet slots |
| Encounter level scaling | `EncounterLevelResolverTests` | Chapter span |

**Not here:** `ArtCatalog` cross-refs (`TrinketTests/Content/ArtCatalogIntegrationTests.swift`). `PlayerRosterState` battle-config logic (`TrinketPersistenceTests/PlayerRosterStateTests.swift`).
