# Persistence & Transition Correctness Audit

**Goal:** Strengthen confirmed correctness gaps at persistence and player-state transition boundaries.

## Intent

Fix confirmed persistence or transition issues. A clean pass is valid; do not add guards, logs, seams, or tests solely to create work. Reuse the existing persistence/transition owner; a new seam requires repeated confirmed violations and the proposal bar in [README.md](README.md).

## Hard stops

- Do not run full-repo concurrency or type-safety sweeps here — link out.
- Audio playback handling belongs to SideEffectSurfaceAudit.

## Triage

| Priority | Examples |
|----------|----------|
| P0 | Double reward grant, silent save failure, crash on corrupt save |
| P1 | Non-idempotent completion, lost persistence error |
| P2 | Recovery hides a meaningful failure from both the player and diagnostics |
| P3 | Style-only error handling churn |

Prioritize P0–P1 among confirmed findings.

## Domain rules

- Critical save fields validated; corrupt saves fail cleanly or fall back with logging — not silent invalid game state.
- `PlayerSaveStore` surfaces write failures (`lastPersistenceError`); silent save failure is data loss.
- Mutations update `modifiedAt` and sanitize via `PlayerSaveSanitizer` where applicable; debounced writes coalesce without duplicate/stale/out-of-order persistence.
- Stage completion / reward grant: double “Continue” must not double-grant; `adjustedMaterialRewards` is pure for the same inputs.
- Suspect silent `try?` on save, sync, battle outcome, or state transitions. **Allowlist:** non-fatal audio (`Trinket/Audio/`).
- Store load failure → default/in-memory recovery + log, not crash.
- Prefer existing coverage. Add a regression only when the test-addition gate passes; battle edges use `rngSeed: 0`, and store edges use the existing empty/partial/corrupt recovery owners.

## Evidence bar

User-visible failure, reproducible data corruption, non-idempotent transition, or silent persistence error path.
