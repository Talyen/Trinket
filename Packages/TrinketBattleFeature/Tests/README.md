# TrinketBattleFeature Tests

BattleFeature test ownership follows [Testing.md](../../../Docs/Platform/Testing.md).
Deterministic presentation contracts merit additions only under its high-value
threshold or rare medium-value exception rule; tests that only mirror styling or
constants do not establish useful regression protection. Apply the same value
rubric to directly related retirement candidates.

## Ownership matrix

| Boundary | Starting points |
|---|---|
| Session lifecycle, artwork pins and activation | `BattleSessionPreparationTests` |
| Commands, turn/auto-end, finishing taps and cast parity | `BattleSessionSimulationTests`, `BattleSessionAutoBattleTests` |
| Cues, gestures and viewport geometry | `BattleSessionCardCueTests`, `BattleCardGesturePolicyTests`, `BattleHandLayoutTests` |
| Projection, attack timing, rewards and spectacle | `BattlePresentationProjectionTests`, `BattleActionPresentationTests`, `BattleSpectacleSessionTests`, victory suites |
| Feedback semantics, delivery and resources | `CombatFeedbackPresenterTests`, `BattleFeedbackLaneTests`, chip/effect/raster/texture suites |
| Committed-result sound selection | `CombatSFXMapperTests` |

The test tree supplies the complete inventory; extend the suite whose assertions
already own the outcome. Keep consuming-outcome tests for fixture defaults.

Runtime-contract behavior is exercised here through `BattleSession` (see
`BattleEngine` and [`Docs/AgentContext/battle-runtime.md`](../../../Docs/AgentContext/battle-runtime.md)); there is no separate runtime test target.

## AppState launch helper vs BattleFeature DTO packer

Keep both. They are not duplicates:

- `PlayBattleLaunchTestSupport` in `TrinketAppStateTests` wraps `PlayBattleCoordinator.assembleLaunch` (Persistence + AppState).
- `BattleRunConfigurationTestSupport` in `TrinketBattleFeatureTests` packages explicit launch DTOs and must stay Persistence- and AppState-free.

Package execution follows the [package testing guide](../README.md#testing) and
[Verification](../../../Docs/Platform/Verification.md#execution-limits).
