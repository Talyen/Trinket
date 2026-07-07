# Side-Effect Surface Audit

Goal: Side effects (I/O, shared/global mutation, non-deterministic primitives) confined to designated seams; zero in pure logic and domain models.

## Targets

Run from repo root:

```bash
# Unseeded randomness / clocks — target 0 in core rule packages
rg -n '(?<!\(using: &[^)]*)\.(random\(|randomElement\(|shuffle\()|(?<!using: &[^)]*)UUID\(\)|Date\(\)' \
  --type swift -g '!*Tests*' -g '!**/Generated/*' -g '!**/rng*' \
  Packages/BattleEngine/Sources/BattleEngine Packages/TrinketCore/

# Seeded RNG in battle simulation is allowed (e.g. Double.random(using: &context.rng)).
# Tooling under BattleBalanceTools/ and BalanceSweepCLI/ is excluded from the target above.

# UserDefaults — allowed seams only
rg -n 'UserDefaults|UserDefaults\.standard' --type swift -g '!*Tests*'
# Expected: OptionsStore, SessionStateStore, PlayerSaveFileStore (legacy migration), AppState wiring

# File I/O — persistence + documented tooling
rg -n 'FileManager|write\(to:|\.write\(' --type swift -g '!*Tests*' -g '!**/Generated/*'
# Expected: TrinketPersistence/ and BalanceSweepCLI/ (balance report output)

# AVFoundation playback types
rg -n 'AVPlayer|AVAudioEngine|MPMusicPlayer' --type swift -g '!*Tests*'
# Expected: 0 matches (Trinket/Audio/ uses AVAudioPlayer)

# CloudKit
rg -n 'CloudKit|CKContainer|CKRecord' --type swift -g '!*Tests*'
# Expected: TrinketPersistence/ only
```

## Checks

### Deterministic battle engine

- `Packages/BattleEngine/Sources/BattleEngine/` must use `state.rng` or an injected `RandomNumberGenerator` — no unseeded `Double.random(in:)`, `Int.random`, `.randomElement()`, or `UUID()`
- `EffectHandlers` take `RNG` as parameter; verify no handler calls global randomness
- Battle simulation must be reproducible: same seed → same outcome (enforced by `BattleEngineTests` using seed 0)
- `Math.random` analogues in Swift (`Float.random`, `Bool.random`) are forbidden in model/rule code unless passed `using: &rng`
- `BattleBalanceTools/` and `BalanceSweepCLI/` are offline tooling; `Date()` timestamps and sampler RNG are acceptable there

### Persistence boundaries

- [PlayerSaveStore.swift](file:///Users/ryanmcintire/Documents/Trinket/Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore.swift) is the single write-through hub; all disk/CloudKit writes route through it.
- Domain stores (`PlayerRosterStore`, `PlayerInventoryStore`, `PlayerJourneyStore`) mutate in-memory state then delegate persistence — no direct `FileManager` or `JSONEncoder` calls outside `TrinketPersistence`.
- `UserDefaults` is intentional for:
  - `OptionsStore` (theme, volumes, preferences)
  - `SessionStateStore` (tab, in-flight battle, map scroll restoration — not part of `PlayerSave`)
  - `PlayerSaveFileStore` one-time legacy journey migration only
- SwiftData manages CloudKit private database container synchronization natively. [PlayerSaveStore.swift](file:///Users/ryanmcintire/Documents/Trinket/Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore.swift) selects private CloudKit vs local-only configurations during initialization (`disableCloudSync` parameter); test via `-disable-cloud-sync` to isolate.

### Audio side effects

- [Trinket/Audio/](file:///Users/ryanmcintire/Documents/Trinket/Trinket/Audio/) is the sole seam for `AVFoundation` / `AVAudioPlayer` playback.
- Music director and SFX triggers go through catalog types from `TrinketContent` — no raw audio URLs in feature views.
- `AVPlayer`/`AVAudioEngine`/`AVAudioPlayer` references outside [Trinket/Audio/](file:///Users/ryanmcintire/Documents/Trinket/Trinket/Audio/) are violations.

### Non-determinism in UI / orchestration

- SwiftUI `onAppear`, `task`, button actions may trigger async work, but randomness (e.g. battle damage display) must source from the battle outcome, not new `random()` calls.
- Per-battle RNG seeds are generated at the orchestration seam (`BattleRNGSeed` / [BattleSession.swift](file:///Users/ryanmcintire/Documents/Trinket/Trinket/State/BattleSession.swift)), not in `ActiveBattleConfiguration` defaults.
- Content randomness (`ItemGenerator`, `pickMysteryEvent`, etc.) must accept an injected `RandomNumberGenerator`.
- For UI-only randomness (e.g. decorative animation delay/offset), seed within `.onAppear { ... }` or keep it strictly visual/non-stateful — do not initialize it inline at the view definition level where it can recalculate on body evaluation.

### Fixes

- Inject the dependency (RNG, clock, store) as a parameter rather than calling the global.
- Push the effect to the designated seam (persistence → `TrinketPersistence`, audio → `Trinket/Audio/`, battle seed → `BattleSession`, randomness → `state.rng` or injected RNG).
- Add a `// UIStyleCheck: allow - <reason>` bypass comment only when the alternative is worse than the side-effect; aim for zero.
