# TrinketContent Tests

Test ownership for `Packages/TrinketContent/Tests/TrinketContentTests/`.
Tests follow the content domains in `Abilities/`, `Equipment/`, `Encounters/`,
`Roster/`, `Homestead/`, and `Media/`; cross-domain invariants stay at the root.

| Concern | Boundary and starting points |
|---|---|
| Abilities and authored content | `Abilities/` and root catalog-invariant suites: validate operations, descriptions, references, stable IDs and ordered registration. Manifest row validation belongs to codegen. |
| Equipment and transformations | `Equipment/`: seeded item generation, affix ranges and Unique rules. Keep rules independent of stores. |
| Encounters and rewards | `Encounters/`: pure Contract/Voyage generation, shared mode loot, captured scaling, Shop/Mystery pools, and Labyrinth layout. |
| Roster edits and progression | `Roster/`: `PlayerRosterStateTests`, equipment/loadout/talent/scaling, combat-build and max-value suites; use explicit content, access and inventory values. |
| Homestead | `Homestead/`: production/fractions, collection, affordability, tier effects, research and craft rules without save fixtures. |
| Media references | `Media/`: catalog/content cross-references and selected artwork wiring. |

Inspect existing assertions in the relevant directory before extending coverage.
The source tree supplies the complete suite inventory. Trigger-field/schema parity
is enforced by `Scripts/internal/content/content_codegen_triggers.py` against
`Scripts/internal/content/trigger_families/index.json`; generated fields are outputs.

**Not here:** Encounter art presentation wiring
(`Packages/TrinketFeatureSupport/Tests/TrinketFeatureSupportTests/StageMapPresentationTests.swift`)
or durable roster edits
(`Packages/TrinketPersistence/Tests/TrinketPersistenceTests/Inventory/RosterEditPersistenceTests.swift`).
