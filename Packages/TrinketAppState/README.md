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
- `BattleLaunchAssembly` / `BattleRewardAssembly`: pure configuration and display
  assembly from one immutable `BattlePreparationInputs` snapshot. Reward inputs
  adapt to Content's shared `BattleRewardPlan.forEncounter` policy.
  Retry uses that retained launch request with current saved party inputs and a fresh
  combat seed; completion settles its reward plan against the current save.
  Neither reads presentation fields for gameplay inputs.
- `PlayBattlePreparation`: adapts mode content into Content's `EncounterScaling`
  policy, then builds one enemy for inspection and launch. Mode level adjustments
  and enemy power-profile selection stay in Content.
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

`FullGameStore` owns purchase state, entitlement refresh ordering, and explicit
restoration. Its internal `FullGameStorefront` adapter owns StoreKit I/O and
verified delivery acknowledgement capabilities. Every delivery source refreshes
current entitlements before acknowledgement; transaction history never grants
access independently. AppState supplies its transient
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
position preservation. Background and memory cleanup retain the bounded playback
bookmarks so foregrounding resumes the song and lyrics at the paused position.
Ending battle clears stored encounter positions. Music uses ambient `AVAudioPlayer`,
respecting the Ring/Silent switch and mixing with other audio.

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

Media-services reset notifications invalidate the ambient session configuration
and retire active, fading, prepared, and loading music voices. The notification
does not restart playback. Both players reject automatic route, play, and warm
requests until a direct player interaction calls
`AppState.resumeAudioAfterMediaServicesReset(scenePhase:)` in the active scene.
The shell enables its recovery tap observer only while a media-services reset is pending.
Recovery then creates fresh native objects and restores the ambient category,
Ring/Silent behavior, and audio mixing.

`MusicPlayer.readPlayback()` returns the current voice's track, media position,
and playing/positive-volume status for lyric sampling. Prepared voices and outgoing
fades never become the lyric clock. The persisted Boss Lyrics preference defaults
on and crosses into Battle alongside this read capability through
`BattlePresentationDependencies`.

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
Releasing the player shuts down the audio actor independently of any suspended
command. Shutdown cancels catalog warming and pending decodes, releases all native
resources, and permanently rejects later commands; ordinary resource release remains
reusable. Cancelled commands cannot create new catalog warmups.
Media-services resets use the same ordered resource invalidation: queued sounds
and suspended decodes cannot replay, and the retired engine is discarded. The next
playback request after user-initiated recovery constructs a new engine and voice
pool without relaunching the app.

## Testing

Use the [verification procedure](../../Docs/Platform/Verification.md#confidence-ladder)
for task checks and explicit package diagnostics.

`Support/AppTestContext.swift` builds isolated states (temp directory plus
`UserDefaults` suite, torn down with the context). It defaults to full-game
access — pass `contentAccess:` when a test needs anything else — and wires a
silent battle runtime connected to PlaySession's production progression delegate.
Normal contexts cache an in-memory save; constructing another state in that context is not a disk
reload. Durability tests inject a file-backed `PlayerSaveStore` and independently
reopen that store. Test arguments
stack on `-disable-cloud-sync -disable-audio -skip-starter-selection`; add
`-reset-state` for a fresh save or `-seed-test-progress` for progressed content.
`Support/LabyrinthTestSupport.swift` covers map setup and reachable-node lookup;
`Support/PlayBattleLaunchTestSupport.swift` covers party setup and bare launch
assembly and enforces settled retry state after its bounded wait. `#if DEBUG` retry tests use
`forcesNextSaveFailure` to drive the unbounded `performSaveAction` paths.
