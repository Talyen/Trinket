# TrinketAppState-local guide

Keep `AppState` as composition/wiring. `PlaySession` is the Play shell and mode
registry: shared battle launch, victory routing, and shell navigation. Mode flow
belongs on `JourneyPlayMode`, `LabyrinthPlayMode`, `SpiresPlayMode`, and
`EncounterPlayMode` — do not grow PlaySession with mode-specific methods. Modes take
constructor-injected collaborators (`PlayerSaveStore`, `BattleSession`, options/SFX,
map-scroll hooks) and explicit cross-mode ports; do not reintroduce a `PlaySession`
back-pointer.

Use Persistence-owned actions for save semantics. Do not forward save slices through
`AppState` or `PlaySession`; views and modes read `PlayerSaveStore` directly. Pass
narrow sessions, values, and actions to app views — inject mode coordinators into the
environment instead of observing the full `PlaySession` when a screen only drives one
mode.

Verify with `./Scripts/test-package.sh TrinketAppState`.

Audio source metadata remains in manifests/catalogs. Do not test live AVFoundation
playback; test deterministic routing and mapping behavior.
