# TrinketAppState

Application composition and player-flow orchestration. Launch/DTO contract:
[battle.md](../../Docs/AgentContext/battle.md). Audio layering: [audio.md](../../Docs/AgentContext/audio.md).

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
code depends on `TrinketBattleRuntime` and feature contracts only — never concrete
BattleFeature. Persistence owns save-mutation semantics; AppState decides when.

```sh
./Scripts/test-package.sh TrinketAppState
```
