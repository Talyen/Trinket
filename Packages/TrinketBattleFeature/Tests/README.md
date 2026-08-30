# TrinketBattleFeature Tests

Ownership for remaining BattleFeature suites. Do not restore layout, glyph,
dissolve, or recipe unit tests — presentation chrome is not a unit-test owner.

## Ownership matrix

| Concern | Suite |
|---------|-------|
| Session lifecycle, auto-battle, prepare/restart | `BattleSession*` (`BattleSessionPreparationTests` owns Session `activatePreparedBattle`) |
| Combat feedback scheduling / presenter | `CombatFeedbackPresenterTests` |
| Victory summary / claimed victory | `BattleVictorySummaryTests`, `BattleClaimedVictoryTests` |

Runtime-contract behavior is exercised here through `BattleSession` (see
`BattleEngine` and [`Docs/AgentContext/battle-runtime.md`](../../../Docs/AgentContext/battle-runtime.md)); there is no separate runtime test target.

## AppState launch helper vs BattleFeature DTO packer

Keep both. They are not duplicates:

- `PlayBattleLaunchTestSupport` in `TrinketAppStateTests` wraps `PlayBattleLaunch.assembleLaunch` (Persistence + AppState).
- `BattleRunConfigurationTestSupport` in `TrinketBattleFeatureTests` packages explicit launch DTOs and must stay Persistence- and AppState-free.

```sh
./Scripts/test-package.sh TrinketBattleFeature
```
