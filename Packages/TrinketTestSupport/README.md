# TrinketTestSupport

Reusable combat and content test fixtures (`CombatantFixtures`, `BattlePartyFixtures`).

Keep fixtures deterministic and independent of app-feature UI and persistence. Do not
put product rules or save-store harnesses here — those live in
`Packages/TrinketPersistence/Sources/TrinketPersistenceTestSupport/` (`SaveTestSupport`).

## Available Fixtures

- `CombatantFixtures`: Deterministic seeds, flexible combatant factories, passive participant helpers (`passiveHero`, `passiveCompanion`, `passiveEnemy`, `passiveCombatant`), and ability builder (`ability`).
- `BattlePartyFixtures`: Standard party assemblies (`standardParty`, `quickWinParty`) with customizable combatants and passive defaults.

Validate fixture changes in consuming packages’ tests before handoff (`BattleEngine`,
`TrinketAppState`, and other consumers). This package has no test target. Shared
conventions: `Docs/Platform/Testing.md`.
