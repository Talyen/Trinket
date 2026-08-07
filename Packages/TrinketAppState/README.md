# TrinketAppState

Application composition and player-flow orchestration.

## Ownership

- `AppState`: app-wide dependency wiring and shell state
- `PlaySession`: Play shell and mode registry — shared battle launch, victory routing,
  and shell navigation
- Mode coordinators (`JourneyPlayMode`, `LabyrinthPlayMode`, `SpiresPlayMode`,
  `EncounterPlayMode`): mode-specific flow; constructor-injected collaborators, no
  `PlaySession` back-pointer
- Encounter session types
- Device-local options and app audio routing
- Environment, deep-link, launch, and shell value types

Music uses `AVAudioPlayer`; SFX use a prestarted `AVAudioEngine` with decoded PCM
buffers. Both use an ambient, mix-with-others audio session. Battle SFX mapping stays
in `TrinketBattleFeature` and reaches playback through
`BattleRuntimeDependencies`. The app composition root supplies that environment
through the closure-only `TrinketBattleRuntime.BattleRuntimeDependencies` contract.

Feature views should receive the narrowest owner: a mode coordinator, `PlaySession`
only for shell concerns, a specific encounter session, `BattleSession`, or explicit
values/actions — not the entire `AppState` or full `PlaySession` when a screen drives
one mode. Persistence owns the semantics of save mutations; AppState decides when to
invoke those actions. Production AppState depends on the SwiftUI-free battle runtime
and feature contracts only. The app target wires the concrete `TrinketBattleFeature`
implementation; the reverse dependency is forbidden.

## Testing

```sh
./Scripts/test-package.sh TrinketAppState
```

Keep AppState, Play/encounter transition, options migration, and audio-routing tests
here.
