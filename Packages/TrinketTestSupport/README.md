# TrinketTestSupport

Battle-party fixtures (`BattlePartyFixtures`) plus re-exports of the shared
combat and content fixtures (`CombatantFixtures`, `ItemFixtures`).

The fixture implementations live in `TrinketContentTestSupport`
(`Packages/TrinketContent/Sources/TrinketContentTestSupport/`) so
`TrinketContentTests` can use them without a package cycle. This package
re-exports those types unchanged; new code should import
`TrinketContentTestSupport` directly.

- `CombatantFixtures`: Canonical seed (`deterministicBattleSeed`, with
  `deterministicBattleSeedVariant(_:)` for independent streams — use it
  directly, no local aliases), flexible combatant factory, and passive presets
  (`passiveHero` / `passiveCompanion` / `passiveEnemy`). Values are
  intentionally not roster-accurate. A `nil` `actionIntervalTurns` means
  catalog/default cadence, not parked; passive means parked
  (`passiveTurnInterval`), quick-win means acts every turn
  (`quickWinTurnInterval`).
- `BattlePartyFixtures`: `quickWinParty` with `hero` / `companion` / `enemy`
  overrides plus `heroAbilities` and `enemyMaxHealth`. The party alone does
  not seed — pair it with a seeded `BattleState` or session helper.
- `ItemFixtures`: Direct inventory-item construction via `makeBareItem` plus
  `baseType` lookups. The helper does not run item generation: affixes default
  to empty and stored powers to `nil`; callers can supply `affixes` and
  `affixPowers` explicitly. Omitted stored powers exercise catalog fallback
  when affixes are supplied. For items produced by the generator, use
  `SaveTestSupport.makeGeneratedItem`. Default IDs are `"<base>-test"`, so
  pass explicit `id`s when a test holds two items on the same base.

Fixture contracts (seed, defaults, ID scheme, name derivation) are pinned by
`FixtureContractTests` in `TrinketContentTests`.

Path-scoped `./Scripts/handoff.sh --isolate --paths <files...>` automatically
validates fixture source and package-manifest changes in all consuming packages’
tests (`BattleEngine`, `TrinketAppState`, `TrinketBattleFeature`, `TrinketFeatureSupport`).
Fixture-only source changes do not require an app build or UI smoke.
This package has no test target. Shared conventions: `Docs/Platform/Testing.md`.
