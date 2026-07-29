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
`BattlePresentationEnvironment`.

Feature views should receive the narrowest owner: a mode coordinator, `PlaySession`
only for shell concerns, a specific encounter session, `BattleSession`, or explicit
values/actions — not the entire `AppState` or full `PlaySession` when a screen drives
one mode. Persistence owns the semantics of save mutations; AppState decides when to
invoke those actions. This package may compose `TrinketBattleFeature`; the reverse
dependency is forbidden.

## Testing

```sh
./Scripts/test-package.sh TrinketAppState
```

Keep AppState, Play/encounter transition, options migration, and audio-routing tests
here.
