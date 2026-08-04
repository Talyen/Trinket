# TrinketAppState-local guide

Keep `AppState` as composition/wiring only — bootstrap, environment injection, and
shell scene wiring. Refuse new feature methods on `AppState` unless they are
bootstrap or composition. Do not expose a parallel `AppState.battle` handle; shell and
views use `PlaySession.battle` (`appState.play.battle`).

`PlaySession` is the Play shell and mode registry: pending destination, map scroll,
and public entry points that forward to shared lifecycle helpers. Assemble modes via
`PlayModeGraph` (fully wired at init — no deferred `bind` steps). Shared battle
lifecycle glue belongs on `PlayBattleLaunch` and `PlayBattleCompletion`; follow the
canonical launch/DTO ownership contract in
[`Docs/AgentContext/battle.md`](../../Docs/AgentContext/battle.md). Do not grow
`PlaySession` with mode-specific prepare/start/complete bodies or move live
roster/inventory/homestead assembly into the Battle DTO.

Mode owners (`JourneyPlayMode`, `LabyrinthPlayMode`, `SpiresPlayMode`,
`EncounterPlayMode`) own navigation/session state and mode-unique save writes — not
the shared victory persist→dismiss sequence. Modes take constructor-injected
collaborators (`PlayerSaveStore`, `any BattleRuntime`, options/SFX, map-scroll hooks,
encounters) and completion ports; do not reintroduce a `PlaySession` back-pointer.

Use Persistence-owned actions for save semantics. Do not forward save slices through
`AppState` or `PlaySession`; views and modes read `PlayerSaveStore` directly. Pass
narrow sessions, values, and actions to app views — inject mode coordinators into the
environment instead of observing the full `PlaySession` when a screen only drives one
mode.

Verify with `./Scripts/test-package.sh TrinketAppState`.

Audio source metadata remains in manifests/catalogs. Do not test live AVFoundation
playback; test deterministic routing and mapping behavior.
