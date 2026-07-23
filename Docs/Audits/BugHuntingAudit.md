# Strategic Bug Hunting Audit

**Goal:** Find and fix real defects with targeted probes — no file-by-file browsing.

## Intent

Confirm candidate defects and write a plan to fix all identified issues (breaking into phases if the scope is large). A pass with no confirmed defect is successful. Do not re-run sibling audits’ full suites; defer P4/P5 by default. Significant structural remedies are proposals per [README.md](README.md).

## Hard stops

- Do not rename/restyle or opportunistically refactor unrelated code. Fix the confirmed bug’s root cause; larger structural remedies are proposals, not unsupervised rewrites.
- Do not expand into speculative backlog or touch manifests/assets/music unless they directly cause the confirmed defect.

## Confirmation policy

- **Auto-fix** P0–P2 correctness bugs (crashes, data loss, double grants, stuck state, clear wrong behavior).
- **Skip and note** balance retunes, player-facing copy/layout design choices, or ambiguous product intent — do not block waiting for answers.
- Never ask about naming, file structure, or obvious internal guards.

## Severity

| Sev | Criteria | Default disposition |
|-----|----------|---------------------|
| P0 | Crash / data loss / double reward / save corruption | Fix now |
| P1 | Wrong battle/progress/UI state | Fix now |
| P2 | Degraded UX (stuck spinner, missing dismiss) | Fix when confirmed and scoped |
| P3 | Recoverable failure without appropriate diagnostics | Fix only if trivial |
| P4 | Maintainability (orphaned state) | Defer to DeadCodeRatioAudit |
| P5 | Future concurrency risk | Defer to SwiftConcurrencyDataRaceAudit |

## Probe hints

- **Collection Bounds & Subscript Risks:** Search for direct array subscripting `[index]` or `.remove(at: index)` in `BattleEngine` and `State/` lacking `indices.contains(index)` or `!isEmpty` protection.
- **Rapid Tap & Double-Trigger State Races:** Search for interactive `Button` actions or `.onTapGesture` handlers mutating state (`appState.startStage`, `forgeActiveLabyrinthCraft`, `claimRewards`) that do not disable buttons during async execution.
- **Leaked Timers & Un-cancelled Background Tasks:** Search for `Timer.publish`, `CADisplayLink`, or `Task { ... }` in stored properties; verify tasks are cancelled in `deinit` / `.onDisappear` or weakly capture `[weak self]`.
- **Arithmetic Underflow / Overflow Risks:** Search for unchecked integer subtraction (`gold - cost`, `hp - damage`, `xp - cost`) where negative values could corrupt store values or cause overflow traps; check for `max(0, ...)` bounds.
- **Silent `try?` on Orchestration Paths:** Search for `try?` on save, stage completion, or battle state transitions (allowing non-fatal audio playback in `Trinket/Audio/`).
- **Orphaned Async Subtasks:** Search for `.task` blocks spawning detached or child tasks that outlive parent view cancellation.
