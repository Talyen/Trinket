# Battle runtime and app-launch context

Load for `TrinketBattleRuntime`, `BattleSession` lifecycle/commands, prepared activation, or `TrinketAppState` battle launch and completion.

`BattleSession` implements `BattleRuntime` and coordinates mutable `BattleState`, simulation, commands, and lifecycle. App orchestration receives it only through the runtime contract. The app composition root supplies `BattleRuntimeDependencies` as closure-only capabilities and builds one concrete session; `PlaySession.battle` receives that object through the contract.

`PlaySession` stays in the environment for shell concerns such as pending destination and victory routing via `PlayBattleCompletion`. Active battle route metadata is `PlayBattleRunRegistration` in the `BattleRunKey` registry. Prepared activation requires the current hero, companion, and enemy IDs to match the baked run. A mismatch fails closed: Play must not fall through to a fresh `activate`, which would re-roll RNG and wipe sibling labyrinth prepares. `activatePreparedBattle` consumes only the matched key; other prepared runs remain until `keepPreparedRuns`, a fresh `activate`/`restart`, or `endBattle`. Unprepared starts still use `activate`.

Play screens read save slices from `PlayerSaveStore` directly. Mode types own map/node/floor selection and mode-unique completion writes; they must not re-absorb the shared victory persist→dismiss sequence. `AppState` prepares audio and requests launch state; the app root warms BattleFeature caches. The battle overlay installs presentation context and presents launch-victory chrome once on the retained session. Do not add presentation-only methods to `BattleRuntime`.

Keep `PlaySession` focused on shell navigation and launch/completion orchestration. Do not reintroduce parallel `AppState.battle` handles or presentation-only methods in the runtime contract.
