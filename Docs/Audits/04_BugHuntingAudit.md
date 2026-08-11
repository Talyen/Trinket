# 04. Strategic Bug Hunting Audit

**Goal:** Find and fix real defects — no file-by-file browsing, no speculative backlog.

## Intent

Confirm candidate defects and fix confirmed ones. Follow a candidate's control/data flow across UI entry points, packages, stores, persistence, tests, and authored configuration far enough to identify the root cause and all confirmed manifestations. A pass with no confirmed defect is successful. Do not re-run sibling audits’ full suites; route adjacent findings to their owners while including work necessary to complete the same root-cause fix. Approval-sensitive structural remedies are proposals per [README.md](README.md).

## Hard stops

- Do not rename/restyle or opportunistically refactor unrelated code. Fix the confirmed bug’s root cause; bounded structural correction within an existing owner may ship, while new boundaries, product decisions, live migrations, and high-risk rewrites require approval.
- Do not expand into speculative backlog or touch manifests/assets/music unless they directly cause the confirmed defect.

## Confirmation policy

- **Auto-fix** P0–P2 correctness bugs (crashes, data loss, double grants, stuck state, clear wrong behavior), including the confirmed caller/state/test cluster required to remove the cause completely.
- **Skip and note** balance retunes, player-facing copy/layout design choices, or ambiguous product intent — do not block waiting for answers.
- Never ask about naming, file structure, or obvious internal guards.

## Severity

| Sev | Criteria | Default disposition |
|-----|----------|---------------------|
| P0 | Crash / data loss / double reward / save corruption | Fix now |
| P1 | Wrong battle/progress/UI state | Fix now |
| P2 | Degraded UX (stuck spinner, missing dismiss) | Fix when confirmed and scoped |
| P3 | Recoverable failure without appropriate diagnostics | Fix only if trivial |

Maintainability hits (orphaned state) route to [06_DeadCodeRatioAudit.md](06_DeadCodeRatioAudit.md); future concurrency risk routes to [14_SwiftConcurrencyDataRaceAudit.md](14_SwiftConcurrencyDataRaceAudit.md) — do not track them as low-severity findings here.

## Example signals

Bounds/subscript risks, double-trigger on async actions, leaked timers or uncancelled tasks, arithmetic underflow on store values, silent `try?` on orchestration paths (audio allowlisted), orphaned async subtasks, inconsistent state across entry points, stale configuration branches, and error/retry paths that cannot return to a usable state.
