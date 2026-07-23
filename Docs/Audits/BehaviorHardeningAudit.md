# Persistence & Transition Correctness Audit

**Goal:** Strengthen confirmed correctness gaps at persistence and player-state transition boundaries.

## Intent

Inventory confirmed persistence or transition issues and write a plan to fix all identified gaps (breaking into phases if the scope is large). A clean pass is valid; do not add guards, logs, seams, or tests solely to create work. Reuse the existing persistence/transition owner; a new seam requires repeated confirmed violations and the proposal bar in [README.md](README.md).

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

Prioritize P0–P1 first; write a plan to cover all identified issues (phased if necessary).

## Domain rules

- Critical save fields validated; corrupt saves fail cleanly or fall back with logging — not silent invalid game state.
- `PlayerSaveStore` surfaces write failures (`lastPersistenceError`); silent save failure is data loss.
- Mutations update `modifiedAt` and sanitize via `PlayerSaveSanitizer` where applicable; debounced writes coalesce without duplicate/stale/out-of-order persistence.
- Stage completion / reward grant: double “Continue” must not double-grant; `adjustedMaterialRewards` is pure for the same inputs.
- Suspect silent `try?` on save, sync, battle outcome, or state transitions. **Allowlist:** non-fatal audio (`Trinket/Audio/`).
- Store load failure → default/in-memory recovery + log, not crash.
- Prefer existing coverage. Add a regression only when the test-addition gate passes; battle edges use `rngSeed: 0`, and store edges use the existing empty/partial/corrupt recovery owners.

## Probe hints

- **Async Task Error Handling:** Search for `Task { try await ... }` or `Task { ... }` in `State/`, `Features/`, and `TrinketPersistence/` lacking `do { try ... } catch` or `lastPersistenceError` logging.
- **Non-Atomic Persistence Mutations:** Search for multi-step store mutations where in-memory state (`AppState`, `PlayerSaveStore`) is updated prior to `performBatchMutation` / `scheduleDeferredSave()` without rollback on failure.
- **Silent Decoding & Parsing Fallbacks:** Search for `try? JSONDecoder().decode` or `try? Data(contentsOf:)` where corrupt save data or session state is silently ignored without diagnostic logging or fallback surfacing.
- **Presentation & Dismissal Cleanup Leaks:** Search for `.onDisappear` or `.sheet` / `.fullScreenCover` dismiss bindings; verify transient presentation state (`isResolvingChoice`, `stageMessage`, `activeBattle`) is cleanly reset when user drags to dismiss.
- **Idempotency & Re-entrancy:** Search for stage completion, purchase, or crafting handlers (`completeStage`, `selectActiveMysteryItem`, `forgeActiveLabyrinthCraft`); verify duplicate triggers check boolean completion flags before granting rewards.
- **Persistence Error Visibility:** Search `PlayerSaveStore` and `PlayerSaveSanitizer` for swallowed store unavailable / write failure errors (`lastPersistenceError`).
