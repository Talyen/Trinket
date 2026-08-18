# TrinketBattleFeature Tests

Ownership for remaining BattleFeature suites. Do not restore layout, glyph,
dissolve, or recipe unit tests — presentation chrome is not a unit-test owner.

## Ownership matrix

| Concern | Suite |
|---------|-------|
| Session lifecycle, auto-battle, prepare/restart | `BattleSession*` |
| Combat feedback scheduling / presenter | `CombatFeedbackPresenterTests` |
| Card activation keyword normalize | `CardActivationTests` |
| Victory summary / claimed victory | `BattleVictorySummaryTests`, `BattleClaimedVictoryTests` |

## Two `BattleRunConfigurationTestSupport` enums

Keep both. They are not duplicates:

- `TrinketAppStateTests` wraps `PlayBattleLaunch.assembleLaunch` (Persistence + AppState).
- `TrinketBattleFeatureTests` packages explicit launch DTOs and must stay Persistence- and AppState-free.

```sh
./Scripts/test-package.sh TrinketBattleFeature
```
