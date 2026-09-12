# Battle runtime contract

Load for the runtime boundary, BattleSession, app battle orchestration, or Battle presentation.

## Ownership

`BattleSession` implements `BattleRuntime` and coordinates mutable `BattleState`, simulation, commands, and lifecycle. App orchestration receives it only through the runtime contract. The app composition root supplies `BattleRuntimeDependencies`, builds one concrete session, and connects progression capabilities through the AppState initializer’s `configureBattleRuntime` hook before bootstrap can launch a battle. `PlaySession.battle` receives that object through the runtime contract.

Keep `PlaySession` focused on shell navigation and launch/completion orchestration. Do not add presentation-only methods to `BattleRuntime`.

`BattlePresentationState` owns the combat projection, `BattleFeedbackLane` owns bounded feedback scheduling/raster publication, and `BattleSpectacleState` owns cinematics and outcome timing. Views observe the narrow lane they render. App-level options and audio enter through `BattleRuntimeDependencies`; BattleFeature never imports `TrinketAppState`.

BattleFeature never imports Persistence; save transactions remain outside the runtime.

## Play observation boundaries

Give a view the narrowest owner it needs: a Play mode coordinator, `PlaySession` only for shell navigation/victory routing (including battle activation via `play.battle`), a specific encounter session, `BattleSession`, or a Battle read lane. Play's campaign/explore stack (`PlayBrowsingStack`) must not observe `BattleSession`; the battle overlay (`PlayBattleOverlay`) is a separate observation scope so map chrome does not rebuild on combat ticks. Shell battle routing observes `PlaySession.battle`; do not reintroduce parallel handles or slice facades. Do not pass `AppState` through a feature tree when explicit values and actions suffice.

## Focused contracts

Read the routed contract and load the other when following a call across concerns:

- [Launch and completion](battle-launch.md): preparation, activation, return navigation, reward settlement, and retry. Outcome/Continue wiring also needs this contract.
- [Presentation](battle-presentation.md): retiring display objects, command playback, feedback, spectacle, and card visibility.

Visual prewarm, first-layout, and keep-alive behavior are owned by [ui-performance.md](ui-performance.md).
