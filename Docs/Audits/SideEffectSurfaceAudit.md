# Side-Effect Surface Audit

**Goal:** Confine I/O, shared mutation, and non-deterministic primitives to designated seams — none in pure logic / domain models.

## Intent

Confirm unexpected effect ownership and fix violations using existing seams. A clean pass is valid. A new seam requires repeated confirmed violations, at least three current uses or an enforced boundary, and proposal approval per [README.md](README.md).

## Hard stops

- Audio `try?` + log is acceptable; do not “fix” it into crashing paths.
- Release-shaped CloudKit checklist work belongs in `Docs/Platform/CloudKitPreShipChecklist.md` — not this audit.

## Allowlisted seams

| Effect | Allowed locations |
|--------|-------------------|
| Disk / encoder I/O | `Packages/TrinketPersistence/`; save-store temp-dir harnesses in PersistenceTests / TrinketTests support (`SaveTestSupport`) — not `TrinketTestSupport` |
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

## Evidence bar

A finding is an effect type used outside its allowlisted seam (or unseeded entropy in battle rule code).
