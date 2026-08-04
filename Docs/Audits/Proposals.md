# Audit run memory

The only durable state audit runs keep between passes. Audit guides stay clean re-runnable procedures; run outcomes go in the handoff/commit/PR; entries here exist solely so the next run does not re-discover, re-propose, or re-litigate the same item.

Hygiene:

- Entries are terse: one line of summary plus an evidence pointer (path/symbol), no run logs or diffs.
- Every open proposal states the implementation boundary: the approval-sensitive reason it could not safely ship as a bounded in-pass fix.
- Remove an open proposal once it is implemented or superseded; remove any entry whose evidence pointer no longer exists.
- A rejected proposal or accepted non-finding may be reopened only with new evidence beyond the recorded reason.
- Update the scope baseline only after a completed routine or full pass.

## Scope baseline

Routine passes inventory candidates from changes since this commit (see README run scope and cadence).

| Baseline commit | Set after |
|-----------------|-----------|
| `38c4b072` | routine all-audits pass 2026-08-03 |

## Open proposals

Propose-and-stop items awaiting user approval per the README right-size policy.

| Owning audit | Proposal | Evidence pointer | Implementation boundary | Proposed |
|--------------|----------|------------------|-------------------------|----------|
| StateGravityOwnership | Collapse `PlayView` mystery/shop origin switches into `EncounterPlayMode` UI entry points (store `completeProgress` at begin; delete journey/labyrinth wrappers) | `PlayView.resolveMysteryChoice` / `finishShopEncounter`; `JourneyPlayMode`/`LabyrinthPlayMode` thin wrappers | Cross-mode session ownership rewrite with map-scroll + persist semantics; root deferred for confidence beyond a bounded in-pass patch | 2026-08-03 |
| ChangeLocalityContextEfficiency | Make `Scripts/README.md` sole CI/routing prose owner; trim `Docs/AgentContext/ci-and-project-generation.md` to exceptions + links | Parallel path-scoped verify / self-clean prose co-touched in Ring 1 | Large guidance rewrite across two long owners; easy to drop card-specific exceptions without careful editorial pass | 2026-08-03 |

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
