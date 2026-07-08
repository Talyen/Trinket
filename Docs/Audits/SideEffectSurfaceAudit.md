# Side-Effect Surface Audit

Goal: Confine I/O, shared mutation, and non-deterministic primitives to designated seams — none in pure logic / domain models.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

## Mission

Run the probes, triage unexpected hits, fix the highest-value seam violations (cap **5** fixes), verify, commit.

## Hard stops

- Do not retune balance or change player-facing copy.
- Do not hand-edit `Generated/*`.
- Do not weaken battle RNG determinism (`rngSeed: 0` in tests).
- Audio `try?` + log is acceptable; do not “fix” it into crashing paths.

## Probes

Run from repo root:

```bash
# Unseeded randomness / clocks — expect 0 in core rule packages
rg -n '(?<!\(using: &[^)]*)\.(random\(|randomElement\(|shuffle\()|(?<!using: &[^)]*)UUID\(\)|Date\(\)' \
  --type swift -g '!*Tests*' -g '!**/Generated/*' -g '!**/rng*' \
  Packages/BattleEngine/Sources/BattleEngine Packages/TrinketCore/

# UserDefaults — allowlist: OptionsStore, AppState session keys / wiring
rg -n 'UserDefaults' --type swift -g '!*Tests*'

# File I/O — allowlist: TrinketPersistence/, BalanceSweepCLI/
rg -n 'FileManager|write\(to:|\.write\(' --type swift -g '!*Tests*' -g '!**/Generated/*'

# AV types outside Trinket/Audio/ — expect 0 (app uses AVAudioPlayer in Audio/)
rg -n 'AVPlayer|AVAudioEngine|AVAudioPlayer|MPMusicPlayer' --type swift -g '!*Tests*'

# CloudKit symbols — expect TrinketPersistence (or none if SwiftData-only wiring)
rg -n 'import CloudKit|CKContainer|CKRecord' --type swift -g '!*Tests*'
```

Seeded RNG (`Double.random(using: &context.rng)`) and `BattleBalanceTools/` / `BalanceSweepCLI/` tooling are allowed.

**CloudKit note:** OS-managed SwiftData CloudKit may not import `CloudKit` directly. Absence of `CKRecord` is not a failure if sync is configured via `ModelConfiguration` / container ID in persistence.

## Checks

### Deterministic battle engine

- No unseeded `random` / `UUID()` / `Date()` in `BattleEngine` rule code
- Handlers take injected RNG; same seed → same outcome
- Content randomness (`ItemGenerator`, mystery picks) accepts `RandomNumberGenerator`

### Persistence boundaries

- Disk/CloudKit writes route through `PlayerSaveStore` / `TrinketPersistence`
- Domain stores mutate memory then delegate — no direct `FileManager` / encoder outside persistence
- `UserDefaults` only for options + ephemeral session keys (not `PlayerSave`)

### Audio

- Sole seam: `Trinket/Audio/`
- Feature views use catalog types from `TrinketContent`, not raw URLs

### UI / orchestration

- Battle display randomness comes from battle outcome, not new `random()` calls
- Per-battle seeds generated at orchestration (`AppState.startBattle`), not buried in configuration defaults
- Decorative UI-only randomness must not re-roll on every `body` evaluation

## Fixes

- Inject RNG / clock / store instead of globals
- Push effects to the owning seam (persistence, audio, battle seed)
- Do **not** use `// UIStyleCheck: allow` for side-effect exceptions (that bypass is UI-style only)

## Verification

```sh
./Scripts/check-module-boundaries.sh
./Scripts/lint.sh
# If BattleEngine / Core touched:
./Scripts/test-package.sh BattleEngine
# If persistence touched:
./Scripts/test-package.sh TrinketPersistence
```

## Commit

```
fix(<scope>): confine <effect> to <seam>

- <what moved or injected>
- <tests run>

User-Facing: no
```
