# Side-Effect Surface Audit

Goal: Side effects (I/O, shared/global mutation, non-deterministic primitives) confined to designated seams; zero in pure logic and domain models.

## Targets

- `rg -n '\.random\(|\.randomElement\(|\.shuffle\(|UUID\(\)|Date\(\)' --type swift -g '!*Tests*' -g '!**/Generated/*' -g '!**/rng*'` — target 0 in `Packages/BattleEngine/` and `Packages/TrinketCore/`
- `rg -n 'UserDefaults|UserDefaults\.standard' --type swift -g '!*Tests*'` — should appear only in `OptionsStore` and test helpers
- `rg -n 'FileManager|write\(to:|\.write\(' --type swift -g '!*Tests*' -g '!**/Generated/*'` — should appear only in `TrinketPersistence/`
- `rg -n 'AVPlayer|AVAudioEngine|MPMusicPlayer' --type swift -g '!*Tests*'` — should appear only in `Trinket/Audio/`
- `rg -n 'CloudKit|CKContainer|CKRecord' --type swift -g '!*Tests*'` — should appear only in `TrinketPersistence/`

## Checks

### Deterministic battle engine

- `Packages/BattleEngine/` must use `state.rng` (seeded via `BattleStateTestFactory`) — no direct `Double.random(in:)`, `Int.random`, `.randomElement()`, or `UUID()`
- `EffectHandlers` take `RNG` as parameter; verify no handler calls global randomness
- Battle simulation must be reproducible: same seed → same outcome (enforced by `BattleEngineTests` using seed 0)
- `Math.random` analogues in Swift (`Float.random`, `Bool.random`) are forbidden in model/rule code — always route through `state.rng`

### Persistence boundaries

- `PlayerSaveStore` is the single write-through hub; all disk/CloudKit writes route through it
- Domain stores (`PlayerRosterStore`, `PlayerInventoryStore`, `PlayerJourneyStore`) mutate in-memory state then delegate persistence — no direct `FileManager` or `JSONEncoder` calls outside `TrinketPersistence`
- `UserDefaults` is intentional only for `OptionsStore` (theme, volumes, preferences) — not part of `PlayerSave`
- `PlayerSaveSyncCoordinator` owns CloudKit reconciliation; test via `-disable-cloud-sync` to isolate

### Audio side effects

- `Trinket/Audio/` is the sole seam for `AVFoundation` playback
- Music director and SFX triggers go through catalog types from `TrinketContent` — no raw audio URLs in feature views
- `AVPlayer`/`AVAudioEngine` references outside `Trinket/Audio/` are violations

### Non-determinism in UI

- SwiftUI `onAppear`, `task`, button actions may trigger async work, but randomness (e.g. battle damage display) must source from the battle outcome, not new `random()` calls
- For UI-only randomness (e.g. decorative animations), initialize lazily with `@State var x = { … }()` or `State(initialValue: …)` — not at the view level in `let`/`var`

### Fixes

- Inject the dependency (RNG, clock, store) as a parameter rather than calling the global
- Push the effect to the designated seam (persistence → `TrinketPersistence`, audio → `Trinket/Audio/`, randomness → `state.rng`)
- Add a `// UIStyleCheck: allow - <reason>` bypass comment only when the alternative is worse than the side-effect; aim for zero
