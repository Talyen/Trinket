# BattleEngine Tests

Ownership matrix for combat package tests. Prefer focused unit tests for
handlers and pipelines; use `BattleCardCombatTests` / integration suites for
cross-boundary contracts through `BattleState.playCard` / `endTurn`. If a test does
not fit a row below, add a row rather than stuffing it into an unrelated file.

## Ownership matrix

| Concern | Suite | Example |
|---------|-------|---------|
| Handler apply/tick | `EffectHandlers*Tests` | cleanse removes meter |
| Damage pipeline steps | `DamagePipelineTests`, `CombatPipelineTests` | dodge short-circuit |
| DoT math | `DoTDamageTests`, `DoTMechanicsTests` | burn decay |
| Card combat driver | `BattleCardCombatTests` | opening hand, end turn, enemy cadence |
| Control / Death's Door | `ControlMeter*`, `DeathsDoorEngineTests` | skip next act |
| Build / traits / affixes | `CombatBuildResolverTests`, `*TraitBattleTests`, `AffixReactionBattleTests` | item triggers |
| Catalog ability combos | `AbilityEffectIntegrationTests` | Bloodthorn, Prayer |
| Outcome / log | `BattleOutcomeResolverTests`, `BattleLogReducerTests` | victory rules |
| Balance simulator | `BattleSimulatorTests` | one-off greedy autoplay, parallel parity, ability/affix contrasts |

## Integration through card turns

| Suite | Notes |
|-------|-------|
| `ControlMeterIntegrationTests` | Stun/freeze → skip via endTurn / unplayable cards |
| `CleanseIntegrationTests` | Cleanse abilities via playCard |
| `MitigationIntegrationTests` | Block/Toughness through rounds |
| `RestorationIntegrationTests` | Heal/leech via playCard |
| `StatIntegrationTests` | Stats → damage through playCard |

## Conventions

- Use `BattleStateTestFactory.makeBattle(...)` for deterministic RNG.
- Prefer `BattleTestFixtures` helpers (`playFirstPlayableCard`, `endTurn`, …).
- Public facade: reads + `playCard` / `endTurn` / log lifecycle. Engine mutations are `package`.

```sh
./Scripts/test-package.sh BattleEngine
```

The balance-tool tests are excluded from the default package command. Run them
explicitly for a one-off balance check:

```sh
./Scripts/test-package.sh --include-balance-sweep-tests BattleEngine
```
