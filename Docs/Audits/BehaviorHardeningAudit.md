# Persistence & Transition Correctness Audit

**Goal:** Strengthen confirmed correctness gaps at persistence and player-state transition boundaries.

**Siblings:** concurrency → [SwiftConcurrencyDataRaceAudit.md](SwiftConcurrencyDataRaceAudit.md); force casts → [TypeSafetyAudit.md](TypeSafetyAudit.md); I/O/RNG seams → [SideEffectSurfaceAudit.md](SideEffectSurfaceAudit.md).

## Intent

Fix a small, cohesive set of confirmed high-impact persistence or transition issues. A clean pass is valid; do not add guards or logs solely to create work. If several hits share one missing boundary or invariant, prefer proposing that shared seam over N one-off guards — see [README.md](README.md).

## Hard stops

- Do not retune rewards/balance without an explicit user ask.
- Do not change `accessibilityIdentifier` strings unless removing the control.
- Do not weaken battle test determinism.
- Do not run full-repo concurrency or type-safety sweeps here — link out.
- Audio playback handling belongs to SideEffectSurfaceAudit.

## Triage

| Priority | Examples |
|----------|----------|
| P0 | Double reward grant, silent save failure, crash on corrupt save |
| P1 | Non-idempotent completion, lost persistence error |
| P2 | Recovery hides a meaningful failure from both the player and diagnostics |
| P3 | Style-only error handling churn |

Fix P0–P1 first; stop when the bounded area is clean.

## Domain rules

- Critical save fields validated; corrupt saves fail cleanly or fall back with logging — not silent invalid game state.
- `PlayerSaveStore` surfaces write failures (`lastPersistenceError`); silent save failure is data loss.
- Mutations update `modifiedAt` and sanitize via `PlayerSaveSanitizer` where applicable; debounced writes coalesce without duplicate/stale/out-of-order persistence.
- Stage completion / reward grant: double “Continue” must not double-grant; `adjustedMaterialRewards` is pure for the same inputs.
- Suspect silent `try?` on save, sync, battle outcome, or state transitions. **Allowlist:** non-fatal audio (`Trinket/Audio/`).
- Store load failure → default/in-memory recovery + log, not crash.
- Prefer existing coverage; battle edges use `rngSeed: 0`; store edges cover empty/partial/corrupt recovery.

## Probe hints

`PlayerSaveStore` / `lastPersistenceError` / sanitizer / CloudKit wiring; debounce/coalesce/scheduleWrite; `try!`/`try?`/`fatalError` on persistence and orchestration paths; `completeStage` / grant / reward / Continue.

## Verify

Boundaries + lint; `test-package.sh TrinketPersistence` if stores touched; focused `test.sh unit` if AppState / BattleSession touched.
