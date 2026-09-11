# Battle runtime and presentation context

Load for `BattleEngine` (`BattleRuntime`), `BattleSession` lifecycle/commands, prepared activation, `TrinketAppState` battle launch and completion, or `TrinketBattleFeature` presentation, feedback, spectacle, outcome, and SwiftUI work.

## Runtime and app launch

`BattleSession` implements `BattleRuntime` and coordinates mutable `BattleState`, simulation, commands, and lifecycle. App orchestration receives it only through the runtime contract. The app composition root supplies `BattleRuntimeDependencies`, builds one concrete session, and connects progression capabilities through the AppState initializer’s `configureBattleRuntime` hook before bootstrap can launch a battle. `PlaySession.battle` receives that object through the runtime contract.

`PlaySession` stays in the environment for shell concerns such as pending destination and victory routing via `PlayBattleCompletion`. Active battle route metadata is `PlayBattleRunRegistration` in the `BattleRunKey` registry. Play validates the current hero, companion, and enemy IDs against the baked run before requesting activation. A mismatch fails closed: Play must not fall through to a fresh `activate`, which would re-roll RNG and wipe sibling labyrinth prepares. `activatePreparedBattle(runKey:configurationID:)` consumes only the matched prepared resource. Production launches prepare, register metadata, then activate; failed activation retains a coherent retryable preparation. Other prepared runs remain until pruning, restart, or end; ending clears their registrations along with their runtime resources. Standalone launches without a mode origin still use `activate`. Pruning while active must leave both runtime resources and registrations untouched.

`BattleLaunchAssembly` retains the exact `BattlePreparationInputs` used to build
its configuration and reward presentation. These include the launch request,
party/save inputs, world seed, combat seed, run key, and presentation policy.
Prepared activation compares that complete value with current inputs and requires
the registered configuration ID as well as matching party/enemy identities.
Changed inputs refresh only that run, retaining its combat seed and sibling
preparations. Unchanged inputs reuse the original configuration and simulation;
missing registration or changed identities fail closed until explicitly prepared.

Play screens read save slices from `PlayerSaveStore` directly. Mode types own map/node/floor selection and mode-unique completion writes; they must not re-absorb the shared victory persist→dismiss sequence. `AppState` prepares audio and requests launch state. BattleSession resolves registered presentation context before publishing activation. Restart installs the new registration before restarting the runtime and restores the previous registration if restart fails. The composition root owns the launch-victory preview; the overlay never installs progression callbacks or presentation context. Visual prewarm, first-layout, and keep-alive behavior are owned by [ui-performance.md](ui-performance.md).

Keep `PlaySession` focused on shell navigation and launch/completion orchestration. Do not add presentation-only methods to `BattleRuntime`.

Battle completion and retreat restore the origin's full browsing path without a
navigation animation before ending the runtime. Do not defer this return to a
view's lifecycle callback: battle exits immediately, so the map must already
show the intended destination.
Pending destinations remain for initial launch routing. Both use
`PlayLaunchDestination.navigationPath` for the complete browsing hierarchy.

## Presentation

`BattlePresentationState` owns the combat projection, `BattleFeedbackLane` owns bounded feedback scheduling/raster publication, and `BattleSpectacleState` owns cinematics and outcome timing. Views observe the narrow lane they render. App-level options and audio enter through `BattleRuntimeDependencies`; BattleFeature never imports `TrinketAppState`.

`BattleView` captures its combat projection and spectacle references when composed.
Ending Battle cancels their work and gives the session fresh display objects instead
of clearing the objects held by outgoing views. The runtime is empty immediately,
while the retiring view keeps its last hand, combatants, and outcome until hidden.
Retiring views must not look up replacement display objects from the session. The captured spectacle is supplied through the view environment,
including ultimate overlays. Each spectacle owns its cinematic players; they
release when that presentation retires, so ending a run cannot empty a visible
video layer or release a subsequent run's players.
The debug Preview Lab opts into cinematic playback through its runtime dependencies
and uses the session's preparation method, independently of the gameplay feature flag.

Victory chrome reads a settled award derived from launch-baked quantities; do not re-derive `StageCompletion` policy inside BattleFeature outcome math. Keep shared presentation DTOs in `TrinketFeatureContracts` and lifecycle ownership in `BattleRuntime`.

Opening draws and turn transitions execute synchronously in BattleEngine. Their
recording callback emits checkpoints that BattleFeature projects into immutable
`BattleTransitionFrame` values; the callback never advances rules. Animated and
immediate presentation consume the same resolved transition. `BattleCommandState`
owns readiness and suspension, and all manual/automatic commands use the same gate.
Suspension pauses playback; replacing/ending a run invalidates its generation.
Do not expose incremental draw mutation to BattleFeature or derive readiness from
whether an animation task happens to exist.

Card commands can record draw batches, pre-play and removal checkpoints, and
resolved effect batches through the same boundary. Recording is scoped to the
synchronous command; retained snapshots never retain its recorder. Recording
uses an inout state boundary so recursive calls do not retain full
pre-play state copies. Card announcements accompany their cast while effect
batches retain resolution order. Pack Tactics
keeps its collect-before-play rules while presentation reveals each drawn card
immediately before its automatic play. Nested plays reuse the normal lift, cast,
and feedback lanes. A buffered card with a full visible hand uses a temporary
cast position over the hand without changing the hand or buffer. Card playback
holds command readiness and outcome presentation until the final cast settles;
scene suspension pauses playback and the cast clock.

The app composition root installs presentation lookup, reward settlement, and
completion capabilities once through `BattleSession.configureProgression`. These
closures weakly capture Play; they are independent of overlay appearance. AppState
settles the launch reward plan against final `BattleGoldFlow` and a save snapshot.
`BattleVictorySummary` projects that settlement, and Continue passes the exact value
through `BattleSession.claimVictory(configurationID:summary:)` for validation and
persistence. `BattleCompletionResult` distinguishes completion, stale settlement,
unavailable runs, and storage failure. A stale settlement refreshes the reveal;
storage failure keeps the award available for retry. Already-claimed victories use
the same completion capability without waiting for an overlay. BattleFeature never
imports Persistence or AppState; these capabilities stay outside `BattleRuntime`.
Capacity, reservations, and transaction rules live in
[persistence context](persistence.md). Current combat content only grants Gold;
it must not debit the battle wallet.

Hand cards remain fully opaque whenever visible, including opening and subsequent
draws. Deal motion uses offset and scale without an opacity transition. Battle
entry and exit switch visibility immediately, and the battlefield uses an identity
transition for outcome changes. Fully hidden prewarmed surfaces remain mounted;
played-card cast and dissolve effects retain their own presentation.

## Play observation boundaries

Give a view the narrowest owner it needs: a Play mode coordinator, `PlaySession` only for shell navigation/victory routing (including battle activation via `play.battle`), a specific encounter session, `BattleSession`, or a Battle read lane. Play's campaign/explore stack (`PlayBrowsingStack`) must not observe `BattleSession`; the battle overlay (`PlayBattleOverlay`) is a separate observation scope so map chrome does not rebuild on combat ticks. Shell battle routing observes `PlaySession.battle`; do not reintroduce parallel handles or slice facades. Do not pass `AppState` through a feature tree when explicit values and actions suffice.
