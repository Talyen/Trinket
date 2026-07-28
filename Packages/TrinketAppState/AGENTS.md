# TrinketAppState-local guide

Keep `AppState` as composition/wiring and `PlaySession` as player-flow orchestration.
Use Persistence-owned actions for save semantics. Do not introduce view dependencies
or forward save slices through AppState. Pass narrow sessions, values, and actions to
app views.

Verify with `./Scripts/test-package.sh TrinketAppState`.

Audio source metadata remains in manifests/catalogs. Do not test live AVFoundation
playback; test deterministic routing and mapping behavior.
