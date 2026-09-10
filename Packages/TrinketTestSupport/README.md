# TrinketTestSupport

Reusable combat and content test fixtures (`CombatantFixtures`, `BattlePartyFixtures`, `ItemFixtures`).

Keep fixtures deterministic and independent of app-feature UI and persistence. Do not
put product rules or save-store harnesses here — those live in
`Packages/TrinketPersistence/Sources/TrinketPersistenceTestSupport/` (`SaveTestSupport`).

## Available Fixtures

- `CombatantFixtures`: Canonical seed (`deterministicBattleSeed`, 1772 — use it directly, no local aliases), flexible combatant factory, and passive presets (`passiveHero` / `passiveCompanion` at 20 HP, `passiveEnemy` at 100 HP). Values are intentionally not roster-accurate; passive means parked (`passiveTurnInterval`), quick-win means acts every turn (`quickWinTurnInterval`).
- `BattlePartyFixtures`: `quickWinParty` with `hero` / `companion` / `enemy` overrides plus `heroAbilities` and `enemyMaxHealth`. The party alone does not seed — pair it with a seeded `BattleState` or session helper.
- `ItemFixtures`: Direct inventory-item construction via `makeBareItem` plus `baseType` lookups. The helper does not run item generation: affixes default to empty and stored powers to `nil`; callers can supply `affixes` and `affixPowers` explicitly. Omitted stored powers exercise catalog fallback when affixes are supplied. For items produced by the generator, use `SaveTestSupport.makeGeneratedItem`. Default IDs are `"<base>-test"`. `TrinketContentTests` carries a mirrored copy because `TrinketContentTests` cannot depend on this package without a cycle — keep signatures in sync.

Validate fixture changes in consuming packages’ tests before handoff
(`BattleEngine`, `TrinketAppState`, `TrinketBattleFeature`, `TrinketFeatureSupport`).
This package has no test target. Shared conventions: `Docs/Platform/Testing.md`.
