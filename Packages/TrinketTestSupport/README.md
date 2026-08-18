# TrinketTestSupport

Reusable combat and content test fixtures (`CombatantFixtures`, battle parties).

Keep fixtures deterministic and independent of app-feature UI and persistence. Do not
put product rules or save-store harnesses here — those live in
`Packages/TrinketPersistence/Sources/TrinketPersistenceTestSupport/` (`SaveTestSupport`).

Validate fixture changes in consuming packages’ tests before handoff (`BattleEngine`,
`TrinketAppState`, and other consumers). This package has no test target. Shared
conventions: `Docs/Platform/Testing.md`.
