# Side-Effect Surface Audit

Goal: Confine I/O, shared mutation, and non-deterministic primitives to designated seams — none in pure logic / domain models.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

## Mission

Run the probes, confirm unexpected effect ownership, and fix a bounded set of high-value seam violations. A clean pass is valid; do not introduce an abstraction merely to move a harmless hit.

## Hard stops

- Do not retune balance or change player-facing copy.
- Do not hand-edit `Generated/*`.
- Do not weaken battle RNG determinism (`rngSeed: 0` in tests).
- Audio `try?` + log is acceptable; do not “fix” it into crashing paths.
- Release-shaped CloudKit checklist work belongs in `Docs/Platform/CloudKitPreShipChecklist.md` — not this audit.

## Allowlisted seams

| Effect | Allowed locations |
|--------|-------------------|
| Disk / encoder I/O | `Packages/TrinketPersistence/`, `BalanceSweepCLI/` (tooling), `Packages/TrinketTestSupport/` temp-dir harnesses |
| `UserDefaults` | Options store + ephemeral shell session keys (tab/battle) — not `PlayerSave` |
| Audio (`AVAudioPlayer`, etc.) | `Trinket/Audio/` only |
| Ultimate cinematic video (`AVPlayer` / `AVPlayerLayer`) | `Trinket/BattleShell/` player cache + battle cinematic overlay host; resolve URLs via `UltimateCinematicCatalog` — do not treat as an audio-seam leak or move into `Trinket/Audio/` |
| Unseeded / wall-clock randomness | Outside `BattleEngine` rule code; battle uses injected RNG |
| Seeded RNG | `Double.random(using: &…)`, `BattleBalanceTools/`, `BalanceSweepCLI/` |
| CloudKit / SwiftData sync | `TrinketPersistence` / `ModelConfiguration` wiring |
| Session / presentation identity (`UUID()`) | Ephemeral `Identifiable` tokens outside `BattleEngine` rule code (battle config, map/rest/craft/shop sessions) — not battle entropy |
| Persistence timestamps (`Date()`) | `TrinketPersistence` `modifiedAt` / equivalent save metadata |

## Probes

Run from repo root. Use simple hit lists, then triage — do **not** rely on variable-length lookbehind (unsupported by default `rg`).

```bash
# Non-determinism candidates in core rule packages — triage each hit
rg -n '\.random\(|randomElement\(|\.shuffle\(|UUID\(\)|Date\(\)|Date\.now|SystemRandomNumberGenerator|ContinuousClock' \
  --type swift -g '!*Tests*' -g '!**/Generated/*' \
  Packages/BattleEngine/Sources/BattleEngine Packages/TrinketCore/

# Ignore / accept when the call injects RNG, e.g. random(using: &context.rng)
# Flag unseeded .random(), UUID(), Date() in BattleEngine rule paths

# UserDefaults — allowlist: OptionsStore, AppState session keys / wiring
rg -n 'UserDefaults' --type swift -g '!*Tests*'

# File I/O — allowlist: TrinketPersistence/, BalanceSweepCLI/, TrinketTestSupport temp dirs
rg -n 'FileManager|Data\(contentsOf:|write\(to:' --type swift -g '!*Tests*' -g '!**/Generated/*'

# AV types — triage audio vs video (do not expect a flat zero)
rg -n 'AVPlayer|AVAudioEngine|AVAudioPlayer|MPMusicPlayer' --type swift -g '!*Tests*'

# CloudKit symbols — expect TrinketPersistence (or none if SwiftData-only wiring)
rg -n 'import CloudKit|CKContainer|CKRecord' --type swift -g '!*Tests*'
```

**AV triage:** `AVAudioPlayer` / engine / music-player types belong only in `Trinket/Audio/`. `AVPlayer` / `AVPlayerLayer` hits in the Ultimate cinematic path are allowlisted when they go through `UltimateCinematicCatalog` — accept those; do not invent a video package solely to clear the probe.

**File I/O triage:** Accept `FileManager` in `Packages/TrinketTestSupport/` when it only creates/removes temporary harness directories.

**CloudKit note:** OS-managed SwiftData CloudKit may not import `CloudKit` directly. Absence of `CKRecord` is not a failure if sync is configured via `ModelConfiguration` / container ID in persistence.

## Checks

### Deterministic battle engine

- No unseeded `random` / `UUID()` / `Date()` in `BattleEngine` rule code
- Handlers take injected RNG; same seed → same outcome
- Content randomness (`ItemGenerator`, mystery picks) accepts `RandomNumberGenerator`

### Persistence boundaries

- Disk/CloudKit writes route through `PlayerSaveStore` / `TrinketPersistence`
- Domain stores mutate memory then delegate — no direct `FileManager` / encoder outside persistence (test-support temp dirs excepted)
- `UserDefaults` only for options + ephemeral shell session keys (tab/battle) — not `PlayerSave`

### Audio

- Sole **audio** seam: `Trinket/Audio/`
- Feature views use catalog types from `TrinketContent`, not raw URLs
- Ultimate cinematic **video** may use `AVPlayer` outside `Trinket/Audio/` when catalog-backed (see allowlist)

### UI / orchestration

- Battle display randomness comes from battle outcome, not new `random()` calls
- Per-battle seeds generated at orchestration (`AppState.startBattle`), not buried in configuration defaults
- Decorative UI-only randomness must not re-roll on every `body` evaluation

## Fixes

- Inject RNG / clock / store instead of globals
- Push effects to the owning seam (persistence, audio, battle seed)
- Keep a direct call when the effect is already owned, deterministic for its use, and does not create a testing or transaction boundary
- Do **not** use `// UIStyleCheck: allow` for side-effect exceptions (that bypass is UI-style only)

## Verification

```sh
./Scripts/check-module-boundaries.sh
./Scripts/lint.sh
# If BattleEngine / Core touched (toolchain permitting):
./Scripts/test-package.sh BattleEngine
# If persistence touched:
./Scripts/test-package.sh TrinketPersistence
```

If Xcode is unavailable, skip package tests and note that in the commit body (see [README.md](README.md) § Cloud / no-Xcode toolchain).

## Commit

```
fix(<scope>): confine <effect> to <seam>

- <what moved or injected>
- <tests run or skipped>

User-Facing: no
```
