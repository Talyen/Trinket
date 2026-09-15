# TrinketAppState

Application composition and player-flow orchestration. Launch/DTO contract:
[launch/completion](../../Docs/AgentContext/battle-launch.md) with the
[common runtime contract](../../Docs/AgentContext/battle-runtime.md). Audio layering: [audio.md](../../Docs/AgentContext/audio.md).

## Ownership

- `AppState`: dependency wiring and shell state
- `PlaySession`: Play shell and mode registry
- Mode coordinators (`JourneyPlayMode`, `LabyrinthPlayMode`, `SpiresPlayMode`,
  `EncounterPlayMode`): constructor-injected collaborators, no `PlaySession` back-pointer
- Battle entry runs through one `PlayBattleLaunch.startBattle` gate
  (paywall → busy → resolve → activate). A busy battle surfaces the failure for
  explicit board/floor taps (Spires/Contracts) and swallows map taps
  (Journey/Labyrinth); a busy transient encounter is always silent. Preparation
  pruning is ownership-preserving: a mode drops only its own stale warms, never
  a sibling's.
- Encounter sessions, device-local options, app audio routing

Production code uses `BattleEngine` (`BattleRuntime`) and feature contracts for its battle
boundary — never concrete BattleFeature. Persistence owns save-mutation semantics;
AppState decides when. The app composition root connects battle progression once
before bootstrap through `configureBattleRuntime`; view appearance is not part of
the reward or completion lifecycle.

`FullGameStore` owns StoreKit product loading, verified purchase ownership,
transaction delivery, and explicit restoration. AppState supplies its transient
access snapshot to the player store and reconciles the party at safe boundaries.
Call `synchronizePurchaseAccess` from the app shell after purchase, restoration,
or foregrounding — never from within a battle or encounter flow; it defers while
gameplay is active. [Purchases](../../Docs/Platform/Purchases.md) owns setup and
release prerequisites.

## Music routing

Only Boss fights resolve to a specific track. Every other battle resolves to the
same stable battle track for a given enemy, regardless of mode. `MusicRoute.resolve`
selects menu music when no battle is active or the selected tab is outside Play.
Browsing a stage preview does not itself start battle music. Menu always uses the
first catalog track; the remaining menu track IDs are alternates the router never
selects.

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

`Support/AppTestContext.swift` builds isolated states (temp directory plus
`UserDefaults` suite, torn down with the context). It defaults to full-game
access — pass `contentAccess:` when a test needs anything else — and wires a
silent battle runtime with the production progression closures. Test arguments
stack on `-disable-cloud-sync -disable-audio -skip-starter-selection`; add
`-reset-state` for a fresh save or `-seed-test-progress` for progressed content.
`Support/LabyrinthTestSupport.swift` covers map setup and reachable-node lookup;
`Support/PlayBattleLaunchTestSupport.swift` covers party setup and bare launch
assembly. Journey, labyrinth, spire, and contracts flows each have their own
test file; shop and mystery encounters share theirs. `#if DEBUG` retry tests use
`forcesNextSaveFailure` to drive the unbounded `retrySaveAction` paths.
