# TrinketTestSupport

Reusable combat and content test fixtures (`CombatantFixtures`, `BattlePartyFixtures`, `ItemFixtures`).

Keep fixtures deterministic and independent of app-feature UI and persistence. Do not
put product rules or save-store harnesses here — those live in
`Packages/TrinketPersistence/Sources/TrinketPersistenceTestSupport/` (`SaveTestSupport`).

## Available Fixtures

- `CombatantFixtures`: Deterministic seeds, flexible combatant factories, and passive participant presets (`passiveHero`, `passiveCompanion`, `passiveEnemy`).
- `BattlePartyFixtures`: Standard party assemblies (`standardParty`, `quickWinParty`) with customizable combatants and passive defaults.
- `ItemFixtures`: Standard inventory item and item base type generators for test targets.

Validate fixture changes in consuming packages’ tests before handoff
(`BattleEngine`, `TrinketAppState`, `TrinketBattleFeature`, `TrinketPersistence`).
This package has no test target. Shared conventions: `Docs/Platform/Testing.md`.
