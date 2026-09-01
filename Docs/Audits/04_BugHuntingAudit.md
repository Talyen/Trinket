# 04. Strategic Bug Hunting Audit

**Goal:** Find and fix real defects — no file-by-file browsing, no speculative backlog.

## Intent

Confirm candidate defects and fix confirmed ones. Follow a candidate's control/data flow across UI entry points, packages, stores, persistence, tests, and authored configuration far enough to identify the root cause and all confirmed manifestations. Do not re-run sibling audits’ full suites; route adjacent findings to their owners while including work necessary to complete the same root-cause fix.

## Hard stops

- Do not rename/restyle or opportunistically refactor unrelated code. Fix the confirmed bug’s root cause within the existing owner.
- Do not expand into speculative backlog or touch manifests/assets/music unless they directly cause the confirmed defect.

## Confirmation policy

- **Auto-fix** P0–P2 correctness bugs (crashes, data loss, double grants, stuck state, clear wrong behavior), including the confirmed caller/state/test cluster required to remove the cause completely.
- **Skip and note** balance retunes, player-facing copy/layout design choices, or ambiguous product intent — do not block waiting for answers.
- Never ask about naming, file structure, or obvious internal guards.

Severity follows the [shared audit scale](README.md#severity-scale). Treat
crashes, data loss, double rewards, and wrong state as the highest-priority
confirmed defects; recoverable diagnostics gaps are optional unless trivial.

Maintainability hits (orphaned, parallel, or ceremonial state) route to [06_DeadParallelCeremonialSurfaceAudit.md](06_DeadParallelCeremonialSurfaceAudit.md); future concurrency risk routes to [14_SwiftConcurrencyDataRaceAudit.md](14_SwiftConcurrencyDataRaceAudit.md) — do not track them as low-severity findings here.

## Example signals

Bounds/subscript risks, double-trigger on async actions, leaked timers or uncancelled tasks, arithmetic underflow on store values, silent `try?` on orchestration paths (audio-seam allowlist lives in [12_SideEffectSurfaceAudit.md](12_SideEffectSurfaceAudit.md)), orphaned async subtasks, inconsistent state across entry points, stale configuration branches, and error/retry paths that cannot return to a usable state.
