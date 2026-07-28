# Battle context

Use for card rules, effects, decks/hands, turn flow, and battle presentation.

| Concern | Owner / entry point |
|---|---|
| Domain primitives | `Packages/TrinketCore` |
| Authored combatants, abilities, stages | `Packages/TrinketContent` and `ContentManifest/` |
| Rules, effect handlers, deck/hand | `Packages/BattleEngine` |
| Battle lifecycle, configuration, outcome, and SwiftUI | `Packages/TrinketBattleFeature` |
| App launch/reward orchestration | `Packages/TrinketAppState` |

For rules, start with `BattleState`, the matching `EffectHandlers/` type, and the
closest test in `Packages/BattleEngine/Tests/`. `BattleState` is a facade: add shared
mutation plumbing in `BattleState+*.swift`; place rule branches in handlers or
engines. Do not put feature calls in the engine.

For presentation, `BattleSession` is the lifecycle/command facade.
`BattlePresentationState` owns the combat projection, `BattleFeedbackLane` owns
bounded feedback scheduling/raster publication, and `BattleSpectacleState` owns
cinematics and outcome timing. Views observe the narrow lane they render. App-level
options and audio enter through `BattlePresentationEnvironment`; Battle never imports
`TrinketAppState`.

For a new effect kind, update registry parity and `EffectHandlersApplyTests`; use a thin integration test only for multi-effect interactions. Use `BattleStateTestFactory.makeBattle(..., rngSeed: 0)` and `EffectHandlers.all`. Do not assert full log prose.

The root task-scoped workflow selects style and package checks. For a narrow rules
iteration, run `./Scripts/test-package.sh BattleEngine`; for Battle presentation, run
`./Scripts/test-package.sh TrinketBattleFeature`. For UI-only battle changes, run
`./Scripts/test.sh smoke SmokeBattleTests` (or the closest focused smoke class /
method). Bare `./Scripts/test.sh smoke` is only the Homestead canary. Read the owning
package README for its test boundary.

Headless balance sweeps: `Packages/BattleEngine/README.md` and `./Scripts/balance-sweep.sh`. Battle layout contracts (three-card hand, art ratios, no top chrome) live in that README.
