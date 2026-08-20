# Battle presentation context

Load for `TrinketBattleFeature` presentation, feedback, spectacle, outcome, or SwiftUI work.

`BattlePresentationState` owns the combat projection, `BattleFeedbackLane` owns bounded feedback scheduling/raster publication, and `BattleSpectacleState` owns cinematics and outcome timing. Views observe the narrow lane they render. App-level options and audio enter through `BattleRuntimeDependencies`; BattleFeature never imports `TrinketAppState`.

Victory chrome uses launch-baked awards; do not re-derive `StageCompletion` policy inside BattleFeature outcome math. Keep shared presentation DTOs in `TrinketFeatureContracts` and lifecycle ownership in `BattleRuntime`.

Use the closest existing BattleFeature semantic test. UI tests are exceptional: add or extend one only for a shipping shell/entry, state-changing journey, or safety invariant that lower tiers cannot own. Handoff routes the package suite and `SmokeBattleTests` when the classifier selects a BattleFeature source path.

For app-level SwiftUI screens outside BattleFeature, load `swiftui-features.md` only when the path is visual.
