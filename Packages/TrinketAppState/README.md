# TrinketAppState

Application composition and player-flow orchestration.

## Ownership

- `AppState`: app-wide dependency wiring and shell state
- `PlaySession`: journey, labyrinth, spire, shop, and mystery orchestration
- Encounter session types
- Device-local options and app audio routing
- Environment, deep-link, launch, and shell value types

Music uses `AVAudioPlayer`; SFX use a prestarted `AVAudioEngine` with decoded PCM
buffers. Both use an ambient, mix-with-others audio session. Battle SFX mapping stays
in `TrinketBattleFeature` and reaches playback through
`BattlePresentationEnvironment`.

Feature views should receive `PlaySession`, a specific encounter session,
`BattleSession`, or explicit values/actions instead of the entire `AppState`.
Persistence owns the semantics of save mutations; AppState decides when to invoke
those actions. This package may compose `TrinketBattleFeature`; the reverse dependency
is forbidden.

## Testing

```sh
./Scripts/test-package.sh TrinketAppState
```

Keep AppState, Play/encounter transition, options migration, and audio-routing tests
here.
