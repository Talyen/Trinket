# Audit proposals and rationale

Current unresolved decisions and unique rationale between audit passes. Run outcomes and actual review coverage
belong in the handoff/commit/PR. Entries here preserve unresolved decisions and
unique implementation rationale; they do not prove that code was reviewed or remains correct.

Hygiene:

- Entries are terse: one line of summary plus an evidence pointer (path/symbol), no run logs or diffs.
- Every open proposal states the implementation boundary: the approval-sensitive reason it could not safely ship as a bounded in-pass fix.
- Remove implemented or superseded proposals. If a pointer no longer resolves, check
  whether the owner was renamed/moved and update it when the rationale still applies;
  remove the entry when its subject or reason no longer applies.
- Keep a conclusion only while its unique rationale affects current decisions; do not
  duplicate standing contracts or keep past verdicts as permanent allowlists.

## Open proposals

Unresolved decisions under the [shared sizing policy](README.md#right-size-policy).
Defer the sensitive portion while continuing independent authorized work.

| Owning audit | Proposal | Evidence pointer | Implementation boundary | Proposed |
|--------------|----------|------------------|-------------------------|----------|
| Performance playbook | Full `PlayerSave` snapshot on every `performBatchMutation` | `PlayerSaveStore.performBatchMutation` and its shared `commit` path in [PlayerSaveStore+Persistence.swift](../../Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore+Persistence.swift) | High-risk rewrite; measure Instruments first | 2026-08-19 |

The snapshot proposal is a measurement-led investigation under the
[performance playbook](../Platform/PerformanceInvestigationPlaybook.md), not evidence
that the persistence owner is misplaced.

## Unique rationale

Revisit these conclusions when their assumptions change. Remove an entry once a
current owner explains the same rationale.

| Owning audit | Candidate | Why retained |
|--------------|-----------|--------------|
| 06 | `StageSelectRowPresentation` stage/spire/labyrinth builders | Mode-specific field sources; a shared config object would add ceremony. |
| 06 | `check-build-cache-paths.sh` divergent path lists | Intentional CI vs local freshness differences; follow the script's input owners. |
