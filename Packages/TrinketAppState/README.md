# TrinketAppState

Application composition and player-flow orchestration. Launch/DTO contract:
[launch/completion](../../Docs/AgentContext/battle-launch.md) with the
[common runtime contract](../../Docs/AgentContext/battle-runtime.md). Audio layering: [audio.md](../../Docs/AgentContext/audio.md).

## Ownership

- `AppState`: dependency wiring and shell state
- `PlaySession`: Play shell and mode registry
- Mode coordinators (`JourneyPlayMode`, `LabyrinthPlayMode`, `SpiresPlayMode`,
  `EncounterPlayMode`): constructor-injected collaborators, no `PlaySession` back-pointer
- Encounter sessions, device-local options, app audio routing

Production code uses `BattleEngine` (`BattleRuntime`) and feature contracts for its battle
boundary — never concrete BattleFeature. Persistence owns save-mutation semantics;
AppState decides when. The app composition root connects battle progression once
before bootstrap through `configureBattleRuntime`; view appearance is not part of
the reward or completion lifecycle.

`FullGameStore` owns StoreKit product loading, verified purchase ownership,
transaction delivery, and explicit restoration. AppState supplies its transient
access snapshot to the player store and reconciles the party at safe boundaries.
[Purchases](../../Docs/Platform/Purchases.md) owns setup and release prerequisites.

## Music routing

`MusicRoute.resolve` selects menu music when no battle is active or the selected
tab is outside Play. An active battle in Play selects its enemy's boss track
when available, otherwise a stable normal battle track. Browsing a stage preview
does not itself start battle music.

`MusicPlayer` preserves track position across route changes, so returning to the
same battle resumes it. Inactive scenes and muted volume route to silence with
position preservation; ending battle and memory cleanup clear stored encounter
positions. Music uses ambient `AVAudioPlayer`, respecting the Ring/Silent switch
and mixing with other audio.

Options prepares the muted track off the main thread so the Music slider can
unmute immediately without a crossfade. Repeated mute reconciles leave that
preparation in place. Track metadata and encoding belong to
[MusicManifest](../../MusicManifest/README.md).

## Sound effects

SFX use a prestarted `AVAudioEngine`. Battle event mapping stays in
`TrinketBattleFeature` via `BattleRuntimeDependencies`.
SFX engine setup, warmup, and playback run on a private audio actor. Commands from
main-actor callers are chained in submission order, so play, stop, and resource release
cannot overtake one another. Catalog decoding stays asynchronous; a cancelled warmup
cannot install its buffers after release. Adding warm voices leaves already-playing
voices running.

## Testing

```sh
./Scripts/test-package.sh TrinketAppState
```
