# Battle runtime and presentation context

Load for `BattleEngine` (`BattleRuntime`), `BattleSession` lifecycle/commands, prepared activation, `TrinketAppState` battle launch and completion, or `TrinketBattleFeature` presentation, feedback, spectacle, outcome, and SwiftUI work.

## Runtime and app launch

`BattleSession` implements `BattleRuntime` and coordinates mutable `BattleState`, simulation, commands, and lifecycle. App orchestration receives it only through the runtime contract. The app composition root supplies `BattleRuntimeDependencies` as closure-only capabilities and builds one concrete session; `PlaySession.battle` receives that object through the contract.

`PlaySession` stays in the environment for shell concerns such as pending destination and victory routing via `PlayBattleCompletion`. Active battle route metadata is `PlayBattleRunRegistration` in the `BattleRunKey` registry. Prepared activation requires the current hero, companion, and enemy IDs to match the baked run. A mismatch fails closed: Play must not fall through to a fresh `activate`, which would re-roll RNG and wipe sibling labyrinth prepares. `activatePreparedBattle` consumes only the matched key; other prepared runs remain until `keepPreparedRuns`, a fresh `activate`/`restart`, or `endBattle`. Unprepared starts still use `activate`.

`BattleLaunchAssembly` retains the exact `BattlePreparationInputs` used to build
its configuration and reward presentation. These include the launch request,
party/save inputs, world seed, combat seed, run key, and presentation policy.
Prepared activation compares that complete value with current inputs and requires
the registered configuration ID as well as matching party/enemy identities.
Changed inputs refresh only that run, retaining its combat seed and sibling
preparations. Unchanged inputs reuse the original configuration and simulation;
missing registration or changed identities fail closed until explicitly prepared.

Play screens read save slices from `PlayerSaveStore` directly. Mode types own map/node/floor selection and mode-unique completion writes; they must not re-absorb the shared victory persist→dismiss sequence. `AppState` prepares audio and requests launch state. The battle overlay installs presentation context and presents launch-victory chrome once on the retained session. Visual prewarm, first-layout, and keep-alive behavior are owned by [ui-performance.md](ui-performance.md).

Keep `PlaySession` focused on shell navigation and launch/completion orchestration. Do not add presentation-only methods to `BattleRuntime`.

## Presentation

`BattlePresentationState` owns the combat projection, `BattleFeedbackLane` owns bounded feedback scheduling/raster publication, and `BattleSpectacleState` owns cinematics and outcome timing. Views observe the narrow lane they render. App-level options and audio enter through `BattleRuntimeDependencies`; BattleFeature never imports `TrinketAppState`.

Victory chrome reads a settled award derived from launch-baked quantities; do not re-derive `StageCompletion` policy inside BattleFeature outcome math. Keep shared presentation DTOs in `TrinketFeatureContracts` and lifecycle ownership in `BattleRuntime`.

Opening draws and turn transitions execute synchronously in BattleEngine. Their
recording callback emits checkpoints that BattleFeature projects into immutable
`BattleTransitionFrame` values; the callback never advances rules. Animated and
immediate presentation consume the same resolved transition. `BattleCommandState`
owns readiness and suspension, and all manual/automatic commands use the same gate.
Suspension pauses playback; replacing/ending a run invalidates its generation.
Do not expose incremental draw mutation to BattleFeature or derive readiness from
whether an animation task happens to exist.

The app overlay installs a reward-settlement capability on `BattleSession` before
presenting outcomes. AppState settles `BattlePresentationContext.rewardPlan` against
final `BattleGoldFlow` and a save snapshot. `BattleVictorySummary` projects the
resulting `BattleRewardSettlement`; Continue passes that exact value back for
validation and persistence. A stale snapshot refreshes the reveal without claiming
or dismissing it. Standalone previews use the same pure settlement operation with
presentation inputs. Keep this capability out of `BattleRuntime`; BattleFeature
must not import Persistence or AppState. Capacity, reservations, and transaction
rules live in [persistence context](persistence.md). Current combat content only
grants Gold; it must not debit the battle wallet.

For app-level SwiftUI screens outside BattleFeature, load `swiftui-features.md` only when the path is visual.

## Play observation boundaries

Give a view the narrowest owner it needs: a Play mode coordinator, `PlaySession` only for shell navigation/victory routing (including battle activation via `play.battle`), a specific encounter session, `BattleSession`, or a Battle read lane. Play's campaign/explore stack (`PlayBrowsingStack`) must not observe `BattleSession`; the battle overlay (`PlayBattleOverlay`) is a separate observation scope so map chrome does not rebuild on combat ticks. Shell battle routing observes `PlaySession.battle`; do not reintroduce parallel handles or slice facades. Do not pass `AppState` through a feature tree when explicit values and actions suffice.
