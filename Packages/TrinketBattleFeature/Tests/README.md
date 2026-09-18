# TrinketBattleFeature Tests

BattleFeature test ownership follows [Testing.md](../../../Docs/Platform/Testing.md).
Deterministic presentation contracts can merit coverage; tests that only mirror
styling or constants do not establish useful regression protection.

## Ownership matrix

| Concern | Suite |
|---------|-------|
| Session lifecycle, prepare/restart/activation | `BattleSessionPreparationTests` (+`Artwork` extension owns artwork-pin lifecycle; `SupportDefaults` pins construction defaults) |
| Session commands, turn/auto-end, overlays, finishing taps | `BattleSessionSimulationTests` (+`CardPlayback` extension owns visual-cast vs settled-combat parity) |
| Card cues (begin/cancel/deny/clear) | `BattleSessionCardCueTests` |
| Auto-battle driving and retry | `BattleSessionAutoBattleTests` |
| Spectacle, ultimate highlights, cinematics | `BattleSpectacleSessionTests` |
| Attack/impact sequencing and timing | `BattleActionPresentationTests` |
| Presentation projection identity | `BattlePresentationProjectionTests` |
| Feedback scheduling, absorption, and expiry | `BattleFeedbackLaneTests` |
| Feedback classification / consolidation | `CombatFeedbackPresenterTests` |
| Chip host delivery and availability | `CombatFeedbackChipPresentationTests` |
| Feedback motion and typography | `CombatFeedbackMotionTests` |
| Card gesture policy | `BattleCardGesturePolicyTests` |
| Effect descriptors and recipe fallbacks | `CombatFeedbackEffectPresentationTests` |
| Raster warmup and invalidation | `CombatFeedbackRasterCatalogTests` |
| SFX mapping | `CombatSFXMapperTests` |
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
