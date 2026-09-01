# BattleEngine Tests

Ownership rules for combat package tests. Prefer focused unit tests for
handlers and pipelines; use `BattleCardCombatTests` / `*IntegrationTests`
suites for cross-boundary contracts through `BattleState.playCard` / `endTurn`.
Extend the suite that already owns a concern; add a new suite only for a
genuinely new concern. The authoritative suite inventory is the
`Tests/BattleEngineTests/` directory; this guide names stable families.

## Ownership rules

| Concern | Suite family |
|---------|--------------|
| Handler apply / status / turn advance | `EffectHandlers*Tests`, `EffectTurnEngineTests` |
| Damage pipeline steps, DoT math | `CombatPipelineTests`, `DoT*Tests` |
| Engine cadence, fight pacing, control states | `BattleTurnEngineTests`, `FightPacingTests`, `ControlMeter*Tests`, `DeathsDoorEngineTests` |
| Cross-boundary card combat | `BattleCardCombatTests` plus `*IntegrationTests` |
| Builds, triggers, talents, traits, affixes, items, trinkets | `CombatBuildResolverTests`, `TalentCatalogRoundTripTests`, `CombatTriggerFieldCoverageTests`, `CombatTriggerTalent*Tests`, `TrinketEffectTests`, `*BattleTests` |
| Catalog ability combos | `AbilityEffectIntegrationTests` |
| Outcome, log, event formatting | `BattleOutcomeResolverTests`, `BattleLogReducerTests`, `EffectSummaryBuilderTests` |
| Balance simulator and sweep tooling | `BattleBalanceToolsTests` (`BattleSimulator*`, `Balance*`, `ModeProgressionToolingTests`); `PlayPolicyTests` stays in `BattleEngineTests` (Auto Battle) |

## Conventions

- Use `BattleStateTestFactory.makeBattle(...)` with its factory default seed
  (`CombatantFixtures.deterministicBattleSeed`) for deterministic RNG. Use
  explicit seeds only for RNG edge cases; seed `0` can invalidate
  dodge-sensitive assertions.
- Use `BattleStateTestFactory.makeMinimalBattle(...)` (or `BattleTestFixtures.makePipelineContext` / `makeContext`) for pipeline tests that must skip deck bootstrap.
- Prefer `BattleTestFixtures` helpers (`playFirstPlayableCard`, `endTurn`, …).
- Dispatch effects through `EffectHandlers.all`.
- Public facade: reads + `playCard` / `endTurn` / log lifecycle. Engine mutations are `package`.

```sh
./Scripts/test-package.sh BattleEngine
```

The balance-tool tests are excluded from the default package command. Run them
explicitly for a one-off balance check:

```sh
./Scripts/test-package.sh --include-balance-sweep-tests BattleEngine
```
