# Persistence, Synchronization & Transition Integrity Audit

**Goal:** Strengthen confirmed integrity gaps across persistence, synchronization, lifecycle, and player-state transaction boundaries.

## Intent

Fix confirmed persistence, synchronization, lifecycle, or transition issues across the complete transaction path. A clean pass is valid; do not add guards, logs, seams, or tests solely to create work. Reuse the existing owner. A bounded architecture-consistent boundary may ship when it is required to make one consequential transaction correct and replaces the unsafe path; new ownership or product policy follows the proposal bar in [README.md](README.md).

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
- Inventory, currency, crafting, encounter, and battle-outcome mutations preserve atomicity/idempotency across validation, in-memory mutation, persistence, retry, and user-visible completion.
- Load, migration, sync, background/foreground, termination, and retry paths must not reorder writes, partially apply a transition, or hide a meaningful recovery state.
- Suspect silent `try?` on save, sync, battle outcome, or state transitions. **Allowlist:** non-fatal audio (`Packages/TrinketAppState/.../Audio/`).
- Store load failure → default/in-memory recovery + log, not crash.
- Prefer existing coverage. Add a regression only when the test-addition gate passes; battle edges use `rngSeed: 0`, and store edges use the existing empty/partial/corrupt recovery owners.

## Evidence bar

User-visible failure, reproducible data corruption, non-idempotent or partially applied transaction, stale/out-of-order persistence, unsafe lifecycle recovery, or silent persistence/synchronization error path. Once confirmed, the remedy may span mutation, persistence, diagnostics or feedback, and the cheapest semantic regression owner.

## Example signals

Silent `try?` on save/sync/battle-outcome paths, reward grants that repeat on a double “Continue”, transitions that mutate before validating, partial inventory/currency updates, retries or lifecycle events that reorder writes, mutations missing `modifiedAt` or sanitizer routing, store load/migration failures that crash instead of recovering with an explicit state and log.
