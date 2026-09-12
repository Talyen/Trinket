# Battle launch and completion

Use with the [common runtime contract](battle-runtime.md) for preparation, activation, return navigation, or reward settlement.

## Preparation and activation

`PlaySession` stays in the environment for shell concerns such as pending destination and victory routing via `PlayBattleCompletion`. Active battle route metadata is `PlayBattleRunRegistration` in the `BattleRunKey` registry. Play validates the current hero, companion, and enemy IDs against the baked run before requesting activation. A mismatch fails closed: Play must not fall through to a fresh `activate`, which would re-roll RNG and wipe sibling labyrinth prepares. `activatePreparedBattle(runKey:configurationID:)` consumes only the matched prepared resource. Production launches prepare, register metadata, then activate; failed activation retains a coherent retryable preparation. Other prepared runs remain until pruning, restart, or end; ending clears their registrations along with their runtime resources. Standalone launches without a mode origin still use `activate`. Pruning while active must leave both runtime resources and registrations untouched.

`BattleLaunchAssembly` retains the exact `BattlePreparationInputs` used to build
its configuration and reward presentation. These include the launch request,
party/save inputs, world seed, combat seed, run key, and presentation policy.
Prepared activation compares that complete value with current inputs and requires
the registered configuration ID as well as matching party/enemy identities.
Changed inputs refresh only that run, retaining its combat seed and sibling
preparations. Unchanged inputs reuse the original configuration and simulation;
missing registration or changed identities fail closed until explicitly prepared.

Play screens read save slices from `PlayerSaveStore` directly. Mode types own map/node/floor selection and mode-unique completion writes; they must not re-absorb the shared victory persist→dismiss sequence. `AppState` prepares audio and requests launch state. BattleSession resolves registered presentation context before publishing activation. Restart installs the new registration before restarting the runtime and restores the previous registration if restart fails. The composition root owns the launch-victory preview; the overlay never installs progression callbacks or presentation context.

Battle completion and retreat restore the origin's full browsing path without a
navigation animation before ending the runtime. Do not defer this return to a
view's lifecycle callback: battle exits immediately, so the map must already
show the intended destination.
Pending destinations remain for initial launch routing. Both use
`PlayLaunchDestination.navigationPath` for the complete browsing hierarchy.

## Reward settlement and completion

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
