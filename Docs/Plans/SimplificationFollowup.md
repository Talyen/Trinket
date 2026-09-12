---
type: execution-plan
status: active
created: 2026-09-01
updated: 2026-09-11
expires: 2026-09-15
---

# Simplification follow-up

## Current disposition

The old Mystery preview-ticket prescription is superseded by
[the saved-offer contract](../Product/MysteryEvents.md#stability-and-completion).
`EncounterPlayMode.beginMysteryEncounter` returns on pin failure and publishes an
ordinary Mystery session only after its offers commit. An unsaved preview ticket
must not override this boundary. This is source confirmation of the current path,
not a new runtime or reload verification.

Codegen correctness is complete: direct access emission replaced fragile
`publicize`/brace counting, with escaping regression coverage. The former blanket
deferral of BattleState/talent regrouping is also superseded by the current
[engine ownership](../AgentContext/battle-engine.md) and
[action contracts](../AgentContext/battle-actions.md).

## Remaining investigation

Damage-resolution rescans and combat-feedback layering remain unverified performance
candidates. No benchmark or improvement is established by this documentation pass.
Use the [performance playbook](../Platform/PerformanceInvestigationPlaybook.md) to
measure the current interaction and owner before proposing snapshots or feedback
deduplication. Preserve gameplay balance, feedback, and artwork budgets. Record a
non-finding if evidence does not justify a bounded change.

Other historical candidates are not a standing backlog. Broad trigger-codegen
changes, phase renaming, reseeding, or removing combat mutation helpers require
new evidence under the existing change policy. Engine phases and presentation
lifecycle remain distinct; hand-buffer and target-resolver consolidations are complete.

## Verification and completion

Any future implementation uses [path-scoped verification](../Platform/Verification.md)
for its actual owners. Keep this plan open for the pending investigation; do not
mark performance work complete from related refactors. On completion or explicit
cancellation, archive its outcome under [Plans](README.md).

This plan retains the residual scope of `ElegantSimplificationRound4` and
`SimplificationConsolidationRound2`; their outcomes remain in the archived ledger
and their full detail in Git history.
