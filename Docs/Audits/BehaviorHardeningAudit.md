# Persistence & Transition Correctness Audit

Goal: Strengthen confirmed correctness gaps at persistence and player-state transition boundaries.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

Concurrency / Sendable → [SwiftConcurrencyDataRaceAudit.md](SwiftConcurrencyDataRaceAudit.md).  
Force casts / unwraps → [TypeSafetyAudit.md](TypeSafetyAudit.md).  
I/O / RNG seams → [SideEffectSurfaceAudit.md](SideEffectSurfaceAudit.md).

## Mission

Probe persistence and transition boundaries, then fix a small, cohesive set of confirmed high-impact issues. A clean pass is valid; do not add guards or logs solely to create work.

## Hard stops

- Do not retune rewards/balance without an explicit user ask.
- Do not change `accessibilityIdentifier` strings unless removing the control.
- Do not weaken battle test determinism.
- Do not run full-repo concurrency or type-safety sweeps here — link out.
- Audio playback handling belongs to [SideEffectSurfaceAudit.md](SideEffectSurfaceAudit.md).

## Probes

```bash
# Save / sync seams (primary)
rg -n 'modifiedAt|lastSynced|lastPersistenceError|disableCloudSync|cloudKitContainer|PlayerSaveStore|PlayerSaveSanitizer' \
  --type swift -g '!*Tests*' .

# Debounced / coalesced writes
rg -n 'debounce|coalesc|scheduleWrite|persist\(|save\(' --type swift \
  Packages/TrinketPersistence Trinket/State -g '!*Tests*' | head -60

# Error escapes on orchestration/save paths — not a hard zero
rg -n 'try!|try\?' --type swift \
  Packages/TrinketPersistence Trinket/State Trinket/BattleShell \
  -g '!*Tests*' -g '!**/Generated/*'

# Hard failures — review each; prefer near-zero outside package inits
rg -n 'fatalError|preconditionFailure|assertionFailure' --type swift \
  Packages/TrinketPersistence Trinket/State Trinket/BattleShell \
  -g '!*Tests*' -g '!**/Generated/*'

# Stage completion / reward idempotency
rg -n 'completeStage|grant|reward|Continue|adjustedMaterialRewards' --type swift \
  Trinket/State Trinket/BattleShell -g '!*Tests*' | head -60
```

Deep `Task` / clock / Sendable probes belong to [SwiftConcurrencyDataRaceAudit.md](SwiftConcurrencyDataRaceAudit.md) — do not duplicate them here.

## Checks

### Persistence & decode

- Critical save fields validated; nil optionals must be semantic, not forgotten migrations
- Corrupt / invalid saves fail cleanly or fall back to safe defaults with logging — not silent invalid game state
- `PlayerSaveStore` surfaces write failures (`lastPersistenceError`); silent save failure is data loss
- Mutations update `modifiedAt` and sanitize via `PlayerSaveSanitizer` where applicable
- Debounced writes coalesce without duplicate/stale/out-of-order persistence

### Idempotent transitions

- `BattleSession` stage completion / reward grant: double “Continue” must not double-grant
- `PlayerHomesteadState.adjustedMaterialRewards` is pure for the same inputs
- Completion and recovery paths remain correct when a transition is retried or interrupted

### Swallowed errors

- Suspect: silent `try?` on save, sync, battle outcome, or state transitions
- **Acceptable allowlist:** non-fatal audio (`Trinket/Audio/`); log when practical
- Store load failure → default/in-memory recovery + log, not crash

### Tests

- Prefer existing coverage; add a focused test only when fixing a gap
- Battle edges: `BattleStateTestFactory.makeBattle(..., rngSeed: 0)`
- Store edges: empty save, migration/partial, concurrent mutate, corrupt payload recovery

## Triage

| Priority | Examples |
|----------|----------|
| P0 | Double reward grant, silent save failure, crash on corrupt save |
| P1 | Non-idempotent completion, lost persistence error |
| P2 | Recovery hides a meaningful failure from both the player and diagnostics |
| P3 | Style-only error handling churn |

Fix P0–P1 first; stop when the bounded transition or persistence area is clean.

## Verification

```sh
./Scripts/check-module-boundaries.sh
./Scripts/lint.sh
./Scripts/test-package.sh TrinketPersistence   # if stores touched; toolchain permitting
./Scripts/test.sh unit <FocusedClass>          # if AppState / BattleSession touched
```

## Commit

```
fix(<scope>): harden <boundary> against <failure mode>

- <fix>
- <test added or reused>

User-Facing: no
```
