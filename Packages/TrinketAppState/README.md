# TrinketAppState

Application composition and player-flow orchestration. Launch/DTO contract:
[battle-runtime.md](../../Docs/AgentContext/battle-runtime.md). Audio layering: [audio.md](../../Docs/AgentContext/audio.md).

## Ownership

- `AppState`: dependency wiring and shell state
- `PlaySession`: Play shell and mode registry
- Mode coordinators (`JourneyPlayMode`, `LabyrinthPlayMode`, `SpiresPlayMode`,
  `EncounterPlayMode`): constructor-injected collaborators, no `PlaySession` back-pointer
- Encounter sessions, device-local options, app audio routing

Music uses ambient `AVAudioPlayer`; SFX use a prestarted `AVAudioEngine`. Committed 0%
music volume still routes to silence; Options prepares the muted track off the main
thread so the Music slider can unmute immediately without a crossfade. Repeated mute
reconciles leave that prepare in place (already-silent `update` does not cancel it). Battle SFX
mapping stays in `TrinketBattleFeature` via `BattleRuntimeDependencies`. Production
code depends on `BattleEngine` (`BattleRuntime`) and feature contracts only — never concrete
BattleFeature. Persistence owns save-mutation semantics; AppState decides when.

SFX engine setup, warmup, and playback run on a private audio actor. Commands from
main-actor callers are chained in submission order, so play, stop, and resource release
cannot overtake one another. Catalog decoding stays asynchronous; a cancelled warmup
cannot install its buffers after release. Adding warm voices leaves already-playing
voices running. Sound buffers, voice counts, gains, and interruption behavior are unchanged.

```sh
./Scripts/test-package.sh TrinketAppState
```
