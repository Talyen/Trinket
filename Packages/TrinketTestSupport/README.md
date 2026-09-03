# TrinketTestSupport

Reusable combat and content test fixtures (`CombatantFixtures`, `BattlePartyFixtures`, `ItemFixtures`).

Keep fixtures deterministic and independent of app-feature UI and persistence. Do not
put product rules or save-store harnesses here — those live in
`Packages/TrinketPersistence/Sources/TrinketPersistenceTestSupport/` (`SaveTestSupport`).

## Available Fixtures

- `CombatantFixtures`: Canonical seed (`deterministicBattleSeed`, 1772 — use it directly, no local aliases), flexible combatant factory, and passive presets (`passiveHero` / `passiveCompanion` at 20 HP, `passiveEnemy` at 100 HP). Values are intentionally not roster-accurate; passive means parked (`passiveTurnInterval`), quick-win means acts every turn (`quickWinTurnInterval`).
- `BattlePartyFixtures`: `quickWinParty` with `hero` / `companion` / `enemy` overrides plus `heroAbilities` and `enemyMaxHealth`. The party alone does not seed — pair it with a seeded `BattleState` or session helper.
- `ItemFixtures`: Bare inventory items via `makeBareItem` plus `baseType` lookups. Bare means no rolled affixes or stored powers (exercises the catalog-fallback path); for rolled items use `SaveTestSupport.makeGeneratedItem`. Default IDs are `"<base>-test"`. `TrinketContentTests` carries a mirrored copy because `TrinketContentTests` cannot depend on this package without a cycle — keep signatures in sync.

Validate fixture changes in consuming packages’ tests before handoff
(`BattleEngine`, `TrinketAppState`, `TrinketBattleFeature`, `TrinketPersistence`).
This package has no test target. Shared conventions: `Docs/Platform/Testing.md`.
