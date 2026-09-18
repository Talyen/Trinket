# BattleEngine Tests

Ownership rules for combat package tests. Prefer focused unit tests for
handlers and pipelines; use `BattleCardCombatTests` / `*IntegrationTests`
suites for cross-boundary contracts through `BattleState.playCard` / `endTurn`.
Extend the suite that already owns a concern; add a new suite only for a
genuinely new concern. Apply [Testing.md](../../../Docs/Platform/Testing.md) to
additions and retirement: prefer representative behavior families and targeted
interaction regressions over per-mechanic or combinatorial matrices.
The authoritative suite inventory is the `Tests/` directory: `BattleEngineTests/`
plus `BattleBalanceToolsTests/` (`BattleSimulator*`, `Balance*`,
`ModeProgressionToolingTests`, `SweepWorkerPoolTests`), which is excluded from
the default package command. This guide names stable families.

Card, turn, trigger, talent, and Unique suites are grouped under `Cards/`,
`Turns/`, `Triggers/`, `Talents/`, and `Uniques/` within `BattleEngineTests/`.
Keep suite extensions with their main declaration; shared factories and handler
helpers live in `Support/`. All remain in the same test target.

## Ownership rules

| Concern | Suite family |
|---------|--------------|
| Handler apply / status / turn advance | `EffectHandlers*Tests`, `EffectTurnEngineTests` |
| Damage pipeline steps, DoT math | `DoT*Tests`, `BattleMechanicsTests`, `ReactionScopeTests` |
| Engine cadence, fight pacing, control states | `BattleTurnEngineTests`, `FightPacingTests`, `ControlMeter*Tests`, `DeathsDoorEngineTests` |
| Cross-boundary card combat | `BattleCardCombatTests` plus `*IntegrationTests` |
| Builds, triggers, talents, traits, affixes, items, trinkets | `CombatBuildResolverTests`, `TalentCatalogRoundTripTests` (+`Damage`/`Capstone*`/`Hero*` splits), `TalentMigrationTests` (legacy trait-trigger side), `CombatTriggerFieldCoverageTests`, `CombatTriggerTalent*Tests` (`Damage`+`Cadence`+`ResourceInteractions`, standalone `Control`), `TrinketEffectTests`, `*BattleTests` |
| Uniques | `UniqueCollectionTests` (+`Cards`/`Damage`/`Defense`/`Resources`; base file holds helpers only) plus `ReturningGaleRegressionTests` |
| Cards, opening hand, assessment, Auto Battle | `BattleCardCombatTests` (+`Buffer`/`BlockTiming`/`Feedback`), `BattleOpeningHandTests`, `BattleCardAssessmentTests`, `PlayPolicyTests` |
| Single-concern mechanics | `BattleChanceTests`, `BattleConditionEvaluatorTests`, `BattleRosterTests`, `BattleStateTests`, `BattleStateStartingHealthTests`, `BattleOutcomeBranchTests`, `CleanseIntegrationTests`, `CombatantBorderAccentTests`, `CombatantBuffAuraTests`, `FaeWardTests`, `HealingReductionTests`, `KeywordCohesionMechanicsTests`, `ManaEmpowermentTests`, `RestorationIntegrationTests`, `RogueRevisionTests` |
| Catalog ability combos | `AbilityEffectIntegrationTests` (including `+Balance`, which stays in this default target despite the name) |
| Outcome, log, event formatting | `BattleOutcomeResolverTests`, `BattleLogReducerTests` |
| Balance simulator and sweep tooling | `BattleBalanceToolsTests` (`BattleSimulator*`, `Balance*`, `ModeProgressionToolingTests`); `PlayPolicyTests` stays in `BattleEngineTests` (Auto Battle) |

## Conventions

- Use `BattleStateTestFactory.makeBattle(...)` with its factory default seed
  (`CombatantFixtures.deterministicBattleSeed`) for deterministic RNG. Use
  explicit seeds only for RNG edge cases; seed `0` can invalidate
  dodge-sensitive assertions, so `seed: 0` sites must be dodge-insensitive
  (block decay, pacing, evaluator) to keep the exception. Wrapper parameters
  named `seed` that forward to `rngSeed` are the ergonomic convention, not a
  re-alias violation; do not introduce unrelated local `let seed = ...`
  constants. Neighbor seeds must use `deterministicBattleSeedVariant(_:)` (or
  range from `deterministicBattleSeed`) so the stream stays greppable — never
  bare `1772` / `1773` literals.
- Health scales are per-concern, not drift: `20/20/100` hero/companion/enemy
  for factory battles, `50/50` pipeline source/target,
  `40/40/200` talent-capstone probes, `1000+` presentation durability probes.
  Do not normalize them toward one default.
- `BattlePerformance.xctestplan` covers UI tests only; `BattlePerformanceScenario`
  has no unit-test participation.
- Build combatants with `CombatantFixtures`. `BattleStateTestFactory` centralizes
  `BattleState` construction; `BattleTestFixtures` composes it for combat scenarios
  and provides play, catalog-build, effect-dispatch, and assertion helpers.
- Use `BattleStateTestFactory.makeMinimalBattle(...)` for pipeline tests that must skip deck bootstrap.
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
