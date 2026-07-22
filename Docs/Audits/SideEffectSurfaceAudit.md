# Side-Effect Surface Audit

**Goal:** Confine I/O, shared mutation, and non-deterministic primitives to designated seams — none in pure logic / domain models.

## Intent

Confirm unexpected effect ownership and fix a bounded set of high-value violations using existing seams. A clean pass is valid. A new seam requires repeated confirmed violations, at least three current uses or an enforced boundary, and proposal approval per [README.md](README.md).

## Hard stops

- Audio `try?` + log is acceptable; do not “fix” it into crashing paths.
- Release-shaped CloudKit checklist work belongs in `Docs/Platform/CloudKitPreShipChecklist.md` — not this audit.

## Allowlisted seams

| Effect | Allowed locations |
|--------|-------------------|
| Disk / encoder I/O | `Packages/TrinketPersistence/`, `Packages/TrinketTestSupport/` temp-dir harnesses |
| `UserDefaults` | Options store + legacy shell-session migration — not `PlayerSave` |
| Audio (`AVAudioPlayer`, etc.) | `Trinket/Audio/` only |
| Ultimate cinematic video (`AVPlayer` / `AVPlayerLayer`) | `Trinket/BattleShell/` player cache + battle cinematic overlay host; resolve URLs via `UltimateCinematicCatalog` — do not treat as an audio-seam leak or move into `Trinket/Audio/` |
| Unseeded / wall-clock randomness | Outside `BattleEngine` rule code; battle uses injected RNG |
| Seeded RNG | `Double.random(using: &…)` in battle/tests; injected RNG seams only |
| CloudKit / SwiftData sync | `TrinketPersistence` / `ModelConfiguration` wiring |
| Session / presentation identity (`UUID()`) | Ephemeral `Identifiable` tokens outside `BattleEngine` rule code (battle config, map/rest/craft/shop sessions) — not battle entropy |
| Persistence timestamps (`Date()`) | `TrinketPersistence` `modifiedAt` / equivalent save metadata |

## Domain rules

- **Battle:** no unseeded `random` / `UUID()` / `Date()` in rule code; handlers take injected RNG; content randomness accepts `RandomNumberGenerator`.
- **Persistence:** player-save disk/CloudKit writes route through `PlayerSaveStore` / `TrinketPersistence`; shell-session writes stay in `PlayerShellSessionStore`; domain stores mutate memory then delegate.
- **AV triage:** audio types only in `Trinket/Audio/`; catalog-backed Ultimate cinematic `AVPlayer` in BattleShell is allowlisted.
- **CloudKit:** OS-managed SwiftData sync may not import `CloudKit` directly — absence of `CKRecord` is not a failure if configured via `ModelConfiguration`.
- **UI:** decorative randomness must not re-roll on every `body`; per-battle seeds generated at orchestration (`AppState.startBattle`), not buried in defaults.
- Do **not** use `// UIStyleCheck: allow` for side-effect exceptions.

## Probe hints

- **Unseeded Randomness & Entropy Leaks:** Search for `.random(`, `SystemRandomNumberGenerator`, `UUID()`, or `Date()` in `Packages/BattleEngine/` and `Packages/TrinketContent/`; verify all calculation paths consume injected RNG (`using: &context.rng`).
- **Non-Deterministic Async Delays:** Search for un-seeded `Task.sleep` or timing dependencies inside battle calculations or simulation tests that compromise replay determinism.
- **Direct System Clock Reads:** Search for `Date()`, `CFAbsoluteTimeGetCurrent()`, or `CACurrentMediaTime()` in duration/cooldown calculations in domain models instead of tick-based counters or monotonic clock abstractions.
- **Global Singleton & Mutable State Access:** Search for `.shared` or global mutable state access (`AppState.shared`, `PlayerSaveStore.shared`) inside pure domain model functions or battle effect handlers.
- **I/O & Persistence Seam Violations:** Search for `FileManager`, `Data(contentsOf:)`, `UserDefaults`, or `Encoder` calls outside `Packages/TrinketPersistence/` and `Trinket/Audio/`.
- **AV & Media Seam Leaks:** Search for `import AVFoundation`, `AVPlayer`, or `AVAudioPlayer` outside `Trinket/Audio/` and `Trinket/BattleShell/`.
