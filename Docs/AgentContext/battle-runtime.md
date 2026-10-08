# Battle runtime contract

Load for the runtime boundary, BattleSession, app battle orchestration, or Battle presentation.

## Ownership

`BattleSession` implements the `BattleRuntime` contract in FeatureContracts and
owns simulation, commands, and visual scheduling. AppState constructs it through
a required factory. PlaySession connects its typed progression delegate before
bootstrap can launch a battle; the session holds that delegate weakly.
App options and audio use `BattlePresentationDependencies` from FeatureContracts.

`PlayBattleCoordinator` owns the sole prepared registry, launch metadata, claims,
Retry, and reward exits. Each prepared registration holds an opaque simulation
handle created by its runtime. Handles reject use after invalidation, consumption,
or runtime teardown, and cannot activate on another runtime. BattleFeature receives
only a `BattlePreparedPreview` projection for selected simulation display and all
prepared artwork configurations. Repeated identical projections do not advance
the presentation revision. Activation consumes only its matched handle after
installation succeeds; siblings survive.

Keep PlaySession focused on application orchestration. BattleRuntime exposes the
preparation projection boundary, never concrete views or save transactions.

`BattlePresentationState` owns the combat projection, `BattleFeedbackLane` owns bounded feedback scheduling/raster publication, and `BattleSpectacleState` owns celebration and outcome timing. Views observe the narrow lane they render. App-level options and audio enter through `BattlePresentationDependencies`; BattleFeature never imports `TrinketAppState`.

Feedback publishes through explicit chip, hit-reaction, and attack-reaction bridges;
its scheduling lane has no observable properties.

BattleFeature never imports Persistence; save transactions remain outside the runtime.

## Play observation boundaries

Give a view the narrowest owner it needs: a Play mode coordinator, `PlaySession` only for shell navigation/victory routing (including battle activation via `play.battle`), a specific encounter session, `BattleSession`, or a Battle read lane. Play's campaign/explore stack (`PlayBrowsingStack`) must not observe `BattleSession`; the battle overlay (`PlayBattleOverlay`) is a separate observation scope so map chrome does not rebuild on combat ticks. Shell battle routing observes `PlaySession.battle`; do not reintroduce parallel handles or slice facades. Do not pass `AppState` through a feature tree when explicit values and actions suffice.

## Focused contracts

Read relevant sections of the routed references and follow calls across concerns:

- [Launch and completion](battle-launch.md): preparation, activation, return navigation, reward settlement, and retry. Outcome/Continue wiring also needs this contract.
- [Presentation](battle-presentation.md): retiring display objects, command playback, feedback, spectacle, and card visibility.

Visual prewarm, first-layout, and keep-alive behavior are owned by [ui-performance.md](ui-performance.md).
