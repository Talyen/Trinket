# Side-Effect Surface Audit

**Goal:** Confine I/O, shared mutation, and non-deterministic primitives to designated seams, and ensure their initiation, lifetime, ordering, cancellation, and failure handling remain owned there — none in pure logic / domain models.

## Intent

Confirm unexpected effect ownership or lifecycle and fix violations using existing seams. A clean pass is valid. A bounded architecture-consistent seam may ship for one consequential enforced boundary when it replaces the violating path and includes its callers; a generic abstraction still requires at least three current uses, while new ownership follows [README.md](README.md).

## Hard stops

- Audio `try?` + log is acceptable; do not “fix” it into crashing paths.
- Release-shaped CloudKit checklist work belongs in `Docs/Platform/CloudKitPreShipChecklist.md` — not this audit.
- A legitimate new effect seam that Architecture supports is not a finding; propose an allowlist-row update per the [README.md](README.md) right-size policy instead of re-flagging it every run.

## Allowlisted seams

| Effect | Allowed locations |
|--------|-------------------|
| Disk / encoder I/O | `Packages/TrinketPersistence/`; save-store temp-dir harnesses in PersistenceTests / TrinketAppStateTests support (`SaveTestSupport`) — not `TrinketTestSupport` |
| `UserDefaults` | Options store + legacy shell-session migration — not `PlayerSave` |
| Audio (`AVAudioPlayer`, etc.) | `Packages/TrinketAppState/.../Audio/` only |
| Ultimate cinematic video (`AVPlayer` / `AVPlayerLayer`) | `Packages/TrinketBattleFeature` player cache + cinematic overlay host; resolve URLs via `UltimateCinematicCatalog` — do not treat as an audio-seam leak or move into app audio |
| Unseeded / wall-clock randomness | Outside `BattleEngine` rule code; battle uses injected RNG |
| Seeded RNG | `Double.random(using: &…)` in battle/tests; injected RNG seams only |
| CloudKit / SwiftData sync | `TrinketPersistence` / `ModelConfiguration` wiring |
| Session / presentation identity (`UUID()`) | Ephemeral `Identifiable` tokens outside `BattleEngine` rule code (battle config, map/rest/craft/shop sessions) — not battle entropy |
| Persistence timestamps (`Date()`) | `TrinketPersistence` `modifiedAt` / equivalent save metadata |

## Domain rules

- **Battle:** no unseeded `random` / `UUID()` / `Date()` in rule code; handlers take injected RNG; content randomness accepts `RandomNumberGenerator`.
- **Persistence:** player-save disk/CloudKit writes route through `PlayerSaveStore` / `TrinketPersistence`; shell-session writes stay in `PlayerShellSessionStore`; domain stores mutate memory then delegate.
- **AV triage:** audio types only in `TrinketAppState` audio sources; catalog-backed Ultimate cinematic `AVPlayer` in `TrinketBattleFeature` is allowlisted.
- **CloudKit:** OS-managed SwiftData sync may not import `CloudKit` directly — absence of `CKRecord` is not a failure if configured via `ModelConfiguration`.
- **UI:** decorative randomness must not re-roll on every `body`; per-battle seeds generated at orchestration (`AppState.startBattle`), not buried in defaults.
- **Lifecycle:** effects must not duplicate because a view recomputes or a retry races; long-lived work has an owner, cancellation/termination path, and explicit ordering where observable state depends on it.
- **Failure/executor:** effect failures are surfaced according to the owning boundary; disk/network/media work must not block the main actor, and cancellation must not be converted into an unrelated error or retry.
- Do **not** use `// UIStyleCheck: allow` for side-effect exceptions.

## Evidence bar

A finding is an effect type used outside its allowlisted seam; unseeded entropy in battle rule code; or source/runtime evidence that an effect is duplicated, reordered, leaked, retriggered by view evaluation, blocks the wrong executor, ignores cancellation, or loses a meaningful failure because initiation/lifetime escaped its owner. Persistence transaction outcomes remain BehaviorHardening findings; actor/data-race hazards remain Concurrency findings.
