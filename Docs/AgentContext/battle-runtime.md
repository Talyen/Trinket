# Battle runtime and presentation context

Load for `TrinketBattleRuntime`, `BattleSession` lifecycle/commands, prepared activation, `TrinketAppState` battle launch and completion, or `TrinketBattleFeature` presentation, feedback, spectacle, outcome, and SwiftUI work.

## Runtime and app launch

`BattleSession` implements `BattleRuntime` and coordinates mutable `BattleState`, simulation, commands, and lifecycle. App orchestration receives it only through the runtime contract. The app composition root supplies `BattleRuntimeDependencies` as closure-only capabilities and builds one concrete session; `PlaySession.battle` receives that object through the contract.

`PlaySession` stays in the environment for shell concerns such as pending destination and victory routing via `PlayBattleCompletion`. Active battle route metadata is `PlayBattleRunRegistration` in the `BattleRunKey` registry. Prepared activation requires the current hero, companion, and enemy IDs to match the baked run. A mismatch fails closed: Play must not fall through to a fresh `activate`, which would re-roll RNG and wipe sibling labyrinth prepares. `activatePreparedBattle` consumes only the matched key; other prepared runs remain until `keepPreparedRuns`, a fresh `activate`/`restart`, or `endBattle`. Unprepared starts still use `activate`.

Play screens read save slices from `PlayerSaveStore` directly. Mode types own map/node/floor selection and mode-unique completion writes; they must not re-absorb the shared victory persist→dismiss sequence. `AppState` prepares audio and requests launch state; the app root warms BattleFeature caches. The battle overlay installs presentation context and presents launch-victory chrome once on the retained session.

Keep `PlaySession` focused on shell navigation and launch/completion orchestration. Do not add presentation-only methods to `BattleRuntime`.

## Presentation

`BattlePresentationState` owns the combat projection, `BattleFeedbackLane` owns bounded feedback scheduling/raster publication, and `BattleSpectacleState` owns cinematics and outcome timing. Views observe the narrow lane they render. App-level options and audio enter through `BattleRuntimeDependencies`; BattleFeature never imports `TrinketAppState`.

Victory chrome uses launch-baked awards; do not re-derive `StageCompletion` policy inside BattleFeature outcome math. Keep shared presentation DTOs in `TrinketFeatureContracts` and lifecycle ownership in `BattleRuntime`.

For app-level SwiftUI screens outside BattleFeature, load `swiftui-features.md` only when the path is visual.
