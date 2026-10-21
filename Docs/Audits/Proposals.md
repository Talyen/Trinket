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
| 01 | Grow shared hero, wallet, and stage-row layouts for larger text | `DetailHeroHeader.swift:45-63`, `WalletPill.swift:52-70`, `StageSelectList.swift:87-92`, `StageSelectActiveCard.swift:122-151` | Shared scroll geometry and player-visible wallet/stage-row layout; needs runtime visual verification at accessibility sizes | 2026-10-20 |
| 02 | Replace authored numeric values in the talent interaction card with manifest references | `Docs/AgentContext/battle-talents.md` vs `ContentManifest/talents.tsv` | Broad de-numbering of the primary talent-interaction guide; needs a readability decision on which counts remain explanatory | 2026-10-20 |
| 09 | Extract the delayed pending-indicator timing/cancellation primitive | `CategoryBrowseShelf.swift:64-70`, `AbilityTierPickerSheet.swift:95-104`, `CombatantDetailPane.swift:118-127`, `HomesteadView.swift:81-100`, `ContractsBoardView.swift:105-113` | A shared helper must stay timing/cancellation-only; per-surface triggers, labels, and spinner placement would add ceremony | 2026-10-20 |
| 16 | Add explicit Retry/Back controls to single-choice Mystery reading when its only choice is rejected | `MysteryEncounterView.swift:253-286` and `EncounterPlayMode+Mystery.swift:128-136` | New player-facing button copy needs product approval and full localization; re-tap unblock ships in-pass | 2026-10-21 |

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
