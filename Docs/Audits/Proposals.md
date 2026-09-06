# Audit run memory

Narrow decision memory between audit passes. Run outcomes and actual review coverage
belong in the handoff/commit/PR. Entries here preserve unresolved decisions and
intentional exceptions; they do not prove that code was reviewed or remains correct.

Hygiene:

- Entries are terse: one line of summary plus an evidence pointer (path/symbol), no run logs or diffs.
- Every open proposal states the implementation boundary: the approval-sensitive reason it could not safely ship as a bounded in-pass fix.
- Remove implemented or superseded proposals. If a pointer no longer resolves, check
  whether the owner was renamed/moved and update it when the rationale still applies;
  remove the entry when its subject or reason no longer applies.
- Revisit rejected proposals and non-findings when new evidence or changed assumptions
  supersede their recorded reason. Do not treat exceptions as permanent allowlists.

## Open proposals

Unresolved decisions under the [shared sizing policy](README.md#right-size-policy).
Defer the sensitive portion while continuing independent authorized work.

| Owning audit | Proposal | Evidence pointer | Implementation boundary | Proposed |
|--------------|----------|------------------|-------------------------|----------|
| 03 | CloudKit `recoveryURL: nil` → in-memory fallback, no delete/recreate | `PlayerSaveStoreConfiguration.resolveStore` CloudKit branch | Live CloudKit still gated by CloudKitPreShipChecklist; needs a recoverable local URL plus a non-network test | 2026-08-19 |
| 03 | `deleteStoreOnFailure: true` wipes progress on any open failure | `PlayerSaveStore.openSaveContainer` | Availability-over-durability product policy; needs SchemaMigrationPlan + backup-before-delete | 2026-08-19 |
| Performance playbook | Full `PlayerSave` snapshot on every `performBatchMutation` | `PlayerSaveStore.performBatchMutation` (`let snapshot = currentSave`) | High-risk rewrite; measure Instruments first | 2026-08-19 |

The snapshot proposal is a measurement-led investigation under the
[performance playbook](../Platform/PerformanceInvestigationPlaybook.md), not evidence
that the persistence owner is misplaced.

## Rejected proposals

Do not re-propose unless new evidence or changed assumptions supersede the reason.

| Owning audit | Proposal | Rejection reason | Decided |
|--------------|----------|------------------|---------|
| _none_ | | | |

## Accepted non-findings

Candidates previously confirmed as intentional or not worth fixing under the recorded
reason. Reuse that conclusion while its assumptions hold.

| Owning audit | Candidate | Why accepted | Decided |
|--------------|-----------|--------------|---------|
| 06 | `BattleRuntime` / `PlayBattleLaunch` | Intentional presentation/runtime and launch seams | 2026-08-05 |
| 06 | Options vs `PlayerSave`; catalog authored vs generated | Architecture hard-stop dual seams | 2026-08-05 |
| 06 | `TrinketFeatureAdapters` module split | Enforced package DAG boundary | 2026-08-05 |
| 06 | `PlayerSaveSanitizer` / labyrinth regeneration | Live save migration; consumer window open | 2026-08-05 |
| 06 | `StageSelectRowPresentation` stage/spire/labyrinth builders | Mode-specific field sources; shared config object would add ceremony | 2026-08-05 |
| 06 | `PlayerSave` / wire aspects decode, ability-ID remaps | Live save consumer window still open; propose only after sunset | 2026-08-05 |
| 06 | `PlayModeGraph` / `LaunchRunCallbacks` | Documented Play assembly owner; not deferred-bind theater | 2026-08-05 |
| 06 | `check-build-cache-paths.sh` divergent path lists | Intentional CI vs local freshness differences; documented | 2026-08-05 |
| 06 | `KeywordShineBorder` vs `CombatantBuffAuraBorder` | Parallel shimmer, but buff aura uses `TrinketDesign.cardShape` (battle 3:4 identity) vs rounded keyword shine | 2026-08-17 |
| 01 | Stage-select placeholder SF Symbols using `Font.system(size:)` | Already `@ScaledMetric`; intentional decorative sizing under audit 01 | 2026-08-17 |
