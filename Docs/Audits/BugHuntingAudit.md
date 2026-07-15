# Strategic Bug Hunting Audit

**Goal:** Find and fix real defects with targeted probes — no file-by-file browsing.

**Siblings:** concurrency → [SwiftConcurrencyDataRaceAudit.md](SwiftConcurrencyDataRaceAudit.md); dead code → [DeadCodeRatioAudit.md](DeadCodeRatioAudit.md); persistence → [BehaviorHardeningAudit.md](BehaviorHardeningAudit.md).

## Intent

Confirm candidate defects and fix up to three highest-value bugs (or one shared root cause). A pass with no confirmed defect is successful. Do not re-run sibling audits’ full suites — only chase hits from this pass; defer P4/P5 by default. Prefer the root-cause remedy over N local patches when related bugs share ownership or an invariant; if that remedy is a significant refactor or architecture change, propose and stop per [README.md](README.md).

## Hard stops

- Do not rename/restyle or opportunistically refactor unrelated code. Fix the confirmed bug’s root cause; larger structural remedies are proposals, not unsupervised rewrites.
- Do not expand into speculative backlog; do not touch manifests (unless a stale catalog ref), assets, music, or hand-edit `Generated/*`.
- Do not alter `accessibilityIdentifier` values unless removing the control.
- Do not weaken `BattleStateTestFactory.makeBattle(..., rngSeed: 0)`.

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

Retain cycles / lifetime (stored closures, Tasks, Timers, delegates); silent `try?` on save / battle outcome / state transitions; `.task` subtasks that outlive cancellation; bounds / `.first!`; grant/reward/completeStage idempotency. Add a focused regression only when it distinguishes the defect from existing coverage.

## Verify

Focused package/unit/smoke for the touched area per `AGENTS.md`; always `lint.sh` + boundaries.
