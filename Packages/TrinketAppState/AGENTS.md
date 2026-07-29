# TrinketAppState-local guide

Keep `AppState` as composition/wiring only — bootstrap, environment injection, and
shell scene wiring. Refuse new feature methods on `AppState` unless they are
bootstrap or composition.

`PlaySession` is the Play shell and mode registry: pending destination, map scroll,
and public entry points that forward to shared lifecycle helpers. Shared battle
lifecycle glue lives on `PlayBattleLaunch` (encounter/loot/claimed-stage resolution,
configure, activate) and `PlayBattleCompletion` (token resolve → mode write → dismiss). Do not
grow `PlaySession` with mode-specific prepare/start/complete bodies. Do not put
mode-branching encounter or loot resolution on `ActiveBattleConfiguration` — that
type only assembles pre-resolved inputs (including claimed-stage policy and gold-find
percent baked at launch).

Mode owners (`JourneyPlayMode`, `LabyrinthPlayMode`, `SpiresPlayMode`,
`EncounterPlayMode`) own navigation/session state and mode-unique save writes — not
the shared victory persist→dismiss sequence. Modes take constructor-injected
collaborators (`PlayerSaveStore`, `BattleSession`, options/SFX, map-scroll hooks)
and explicit cross-mode ports; do not reintroduce a `PlaySession` back-pointer.

Use Persistence-owned actions for save semantics. Do not forward save slices through
`AppState` or `PlaySession`; views and modes read `PlayerSaveStore` directly. Pass
narrow sessions, values, and actions to app views — inject mode coordinators into the
environment instead of observing the full `PlaySession` when a screen only drives one
mode.

Verify with `./Scripts/test-package.sh TrinketAppState`.

Audio source metadata remains in manifests/catalogs. Do not test live AVFoundation
playback; test deterministic routing and mapping behavior.
