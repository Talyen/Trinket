# Audit run memory

The only durable state audit runs keep between passes. Audit guides stay clean re-runnable procedures; run outcomes go in the handoff/commit/PR; entries here exist solely so the next run does not re-discover, re-propose, or re-litigate the same item.

Hygiene:

- Entries are terse: one line of summary plus an evidence pointer (path/symbol), no run logs or diffs.
- Remove an open proposal once it is implemented or superseded; remove any entry whose evidence pointer no longer exists.
- A rejected proposal or accepted non-finding may be reopened only with new evidence beyond the recorded reason.
- Update the scope baseline only after a completed routine or full pass.

## Scope baseline

Routine passes inventory candidates from changes since this commit (see README run scope and cadence).

| Baseline commit | Set after |
|-----------------|-----------|
| `bf5171ae` | full all-audits pass 2026-07-30 |

## Open proposals

Propose-and-stop items awaiting user approval per the README right-size policy.

| Owning audit | Proposal | Evidence pointer | Proposed |
|--------------|----------|------------------|----------|
| _none_ | | | |

## Rejected proposals

Do not re-propose without new evidence beyond the recorded reason.

| Owning audit | Proposal | Rejection reason | Decided |
|--------------|----------|------------------|---------|
| _none_ | | | |

## Accepted non-findings

Candidates confirmed as intentional or not worth fixing. Skip them during triage.

| Owning audit | Candidate | Why accepted | Decided |
|--------------|-----------|--------------|---------|
| _none_ | | | |
