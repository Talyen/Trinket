# Strategic Bug Hunting Audit

**Goal:** Find and fix real defects — no file-by-file browsing, no speculative backlog.

## Intent

Confirm candidate defects and fix confirmed ones. A pass with no confirmed defect is successful. Do not re-run sibling audits’ full suites; route maintainability and concurrency-risk hits to their owning audits by default. Significant structural remedies are proposals per [README.md](README.md).

## Hard stops

- Do not rename/restyle or opportunistically refactor unrelated code. Fix the confirmed bug’s root cause; larger structural remedies are proposals, not unsupervised rewrites.
- Do not expand into speculative backlog or touch manifests/assets/music unless they directly cause the confirmed defect.

## Confirmation policy

- **Auto-fix** P0–P2 correctness bugs (crashes, data loss, double grants, stuck state, clear wrong behavior).
- **Skip and note** balance retunes, player-facing copy/layout design choices, or ambiguous product intent — do not block waiting for answers.
- Never ask about naming, file structure, or obvious internal guards.

## Severity

Shared scale: [README.md](README.md).

| Sev | Criteria | Default disposition |
|-----|----------|---------------------|
| P0 | Crash / data loss / double reward / save corruption | Fix now |
| P1 | Wrong battle/progress/UI state | Fix now |
| P2 | Degraded UX (stuck spinner, missing dismiss) | Fix when confirmed and scoped |
| P3 | Recoverable failure without appropriate diagnostics | Fix only if trivial |

Maintainability hits (orphaned state) route to DeadCodeRatioAudit; future concurrency risk routes to SwiftConcurrencyDataRaceAudit — do not track them as low-severity findings here.

## Example signals

Bounds/subscript risks, double-trigger on async actions, leaked timers or uncancelled tasks, arithmetic underflow on store values, silent `try?` on orchestration paths (audio allowlisted), orphaned async subtasks.
