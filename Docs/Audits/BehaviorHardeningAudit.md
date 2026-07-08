# Behavior Hardening Audit

Goal: Strengthen correctness at persistence, state-machine, and error-handling boundaries.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

Concurrency / Sendable → [SwiftConcurrencyDataRaceAudit.md](SwiftConcurrencyDataRaceAudit.md).  
Force casts / unwraps → [TypeSafetyAudit.md](TypeSafetyAudit.md).

## Mission

Probe persistence and orchestration boundaries, triage by user impact, fix up to **5** high-confidence issues (idempotency, silent save failure, corrupt-save handling), verify, commit.

## Hard stops

- Do not retune rewards/balance without an explicit user ask.
- Do not change `accessibilityIdentifier` strings unless removing the control.
- Do not weaken battle test determinism.
- Audio playback `try?` + log is acceptable.

## Probes

```bash
# Timing / async orchestration (review; deep concurrency owned elsewhere)
rg -n 'Task\s*\{|ContinuousClock|SuspendingClock|withTaskGroup' --type swift -g '!*Tests*' -g '!**/Generated/*'

# Error escapes — review orchestration/save paths (not a hard zero)
rg -n 'try!|try\?' --type swift -g '!*Tests*' -g '!**/Generated/*'

# Hard failures — review each; prefer near-zero outside package inits
rg -n 'fatalError|preconditionFailure|assertionFailure' --type swift -g '!*Tests*' -g '!**/Generated/*'

# Save / sync seams
rg -n 'modifiedAt|lastSynced|lastPersistenceError|disableCloudSync|cloudKitContainer' --type swift -g '!*Tests*'
```

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
- SwiftUI `.task` re-entrance: appear/disappear/reappear must not leak duplicate work

### Swallowed errors

- Suspect: silent `try?` on save, sync, battle outcome, or state transitions
- Acceptable: non-fatal audio; log when practical
- Store load failure → default/in-memory recovery + log, not crash

### Architecture (verify, don’t re-audit imports)

- `./Scripts/check-module-boundaries.sh` clean
- New `EffectKind` registered in `EffectHandlers.all`
- UI tests use stable `accessibilityIdentifier`s

### Tests

- Prefer existing coverage; add a focused test only when fixing a gap
- Battle edges: `BattleStateTestFactory.makeBattle(..., rngSeed: 0)`
- Store edges: empty save, migration/partial, concurrent mutate, corrupt payload recovery

## Triage

| Priority | Examples |
|----------|----------|
| P0 | Double reward grant, silent save failure, crash on corrupt save |
| P1 | Non-idempotent completion, lost persistence error |
| P2 | Missing log on recoverable failure |
| P3 | Style-only error handling churn |

Fix P0–P1 first; cap at 5 fixes.

## Verification

```sh
./Scripts/check-module-boundaries.sh
./Scripts/lint.sh
./Scripts/test-package.sh TrinketPersistence   # if stores touched
./Scripts/test.sh unit <FocusedClass>          # if AppState / BattleSession touched
```

## Commit

```
fix(<scope>): harden <boundary> against <failure mode>

- <fix>
- <test added or reused>

User-Facing: no
```
