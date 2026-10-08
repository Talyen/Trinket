# TrinketAppState

Application composition and player-flow orchestration. Launch/DTO contract:
[launch/completion](../../Docs/AgentContext/battle-launch.md) with the
[common runtime contract](../../Docs/AgentContext/battle-runtime.md). Audio layering: [audio.md](../../Docs/AgentContext/audio.md).

## Ownership

`App/` owns app composition, shell state, and options; `Play/` owns battle and
encounter orchestration plus `Modes/`; `Purchases/` owns StoreKit access;
`Audio/` owns music and sound playback. These folders share one target.

- `AppState`: dependency wiring and shell state
- `PlaySession`: Play shell and mode composition
- `PostBattleTalentChoices`: transient queue, eligibility, and confirmation
  transitions after settled battle rewards; `PlaySession` forwards screen actions
- `PlayBattleCoordinator`: application battle transitions, access policy, prepared
  registrations and active run, reward claims/save retries, keyed presentation exit,
  and Talent baselines across Retry. Each run retains authoritative launch inputs,
  configuration, reward plan, and optional route, including standalone battles.
- `BattleLaunchAssembly` / `BattleRewardAssembly`: pure configuration, reward-plan,
  and display assembly from one immutable `BattlePreparationInputs` snapshot.
  Retry uses that retained launch request with current saved party inputs and a fresh
  combat seed; completion settles its reward plan against the current save.
  Neither reads presentation fields for gameplay inputs.
- Mode coordinators (`JourneyPlayMode`, `LabyrinthPlayMode`, `SpiresPlayMode`,
  `ContractsPlayMode`, `VoyagePlayMode`, `EncounterPlayMode`): constructor-injected
  collaborators, no `PlaySession` back-pointer
- Battle entry runs through one `PlayBattleCoordinator.startBattle` gate
  (paywall → busy → resolve → activate). Mode-specific eligibility and request
  construction run at resolve time. A busy battle returns a rejection value for
  explicit board/floor taps (Spires/Contracts) and swallows map taps
  (Journey/Labyrinth); a busy transient encounter is always silent. The shared
  action-result adapter logs rejections internally and opens the Full Game offer
  for access restrictions; returned diagnostic text is not player-facing. Preparation
  pruning is ownership-preserving under `PlayBattleMode`: a mode drops only its own stale warms, never
  a sibling's.
- Encounter sessions, device-local options, app audio routing

Production code uses `BattleEngine` values and FeatureContracts (`BattleRuntime`) for its battle
boundary — never concrete BattleFeature. Persistence owns save-mutation semantics;
AppState decides when and consumes committed domain results. Unrestricted mutation
closures and receipt collection stay internal to Persistence. The app composition root supplies the required runtime factory. PlaySession
connects its typed progression delegate before bootstrap; view appearance is not part of
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
Browsing a stage preview does not itself start battle music. Menu rotates through
the catalog once per calendar day (stable within the day).

`MusicPlayer` preserves track position across route changes, so returning to the
same battle resumes it. Inactive scenes and muted volume route to silence with
position preservation; ending battle and memory cleanup clear stored encounter
positions. Music uses ambient `AVAudioPlayer`, respecting the Ring/Silent switch
and mixing with other audio.

Options prepares the muted track off the main thread so the Music slider can
unmute immediately without a crossfade. Options requests this preparation after
mute reconciliation. Track metadata and encoding belong to
[MusicManifest](../../MusicManifest/README.md).

`MusicPlayer` owns track transitions: each voice stays paired with its request,
pending work is either loading or prepared, and an outgoing fade has one explicit
teardown owner. Replacing a track saves its position at the actual handoff.
Requested replacements still own that handoff when muted during decoding, so
unmuting previews the requested track. Prewarming alone does not replace a playing route.
Cancelled loads cannot install voices, and cancelled fades cannot overwrite a
new slider gain. `MusicPlaybackBackend` isolates decoding and ambient session
setup; deterministic transition tests use controlled loads and silent fake voices.

## Sound effects

SFX use a prestarted `AVAudioEngine`. Battle event mapping stays in
`TrinketBattleFeature` via `BattlePresentationDependencies`.
The audio actor owns buffer caching, shared in-flight loads, voice pools, and typed
play/warm/stop/release commands. Its internal backend owns AVFoundation decoding,
engine recovery, and native voice operations. Commands from
main-actor callers keep play and warm requests in submission order. Stop and resource
release discard older queued sounds and reach the audio actor even while a foreground
decode is suspended; subsequent requests wait for invalidation to finish. Catalog
prewarming and individual sounds use the same
asynchronous buffer preparation path. Stop and resource release invalidate in-flight
decodes, so stale work cannot reinstall buffers or restart the engine. Adding warm
voices leaves already-playing voices running.

## Testing

Package execution and local diagnostic opt-in follow
[Verification](../../Docs/Platform/Verification.md#execution-limits); routine local
changes use path-scoped handoff.

```sh
./Scripts/test-package.sh TrinketAppState
```

`Support/AppTestContext.swift` builds isolated states (temp directory plus
`UserDefaults` suite, torn down with the context). It defaults to full-game
access — pass `contentAccess:` when a test needs anything else — and wires a
silent battle runtime with the production progression closures. Normal contexts
cache an in-memory save; constructing another state in that context is not a disk
reload. Durability tests inject a file-backed `PlayerSaveStore` and independently
reopen that store. Test arguments
stack on `-disable-cloud-sync -disable-audio -skip-starter-selection`; add
`-reset-state` for a fresh save or `-seed-test-progress` for progressed content.
`Support/LabyrinthTestSupport.swift` covers map setup and reachable-node lookup;
`Support/PlayBattleLaunchTestSupport.swift` covers party setup and bare launch
assembly and enforces settled retry state after its bounded wait. `#if DEBUG` retry tests use
`forcesNextSaveFailure` to drive the unbounded `retrySaveAction` paths.
