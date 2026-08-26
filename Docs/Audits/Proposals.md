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
| `59cef613` | Full Audits 02/05 pass plus agent-output baseline (implementation remains in the working tree) |

## Open proposals

Propose-and-stop items awaiting user approval per the README right-size policy.

| Owning audit | Proposal | Evidence pointer | Implementation boundary | Proposed |
|--------------|----------|------------------|-------------------------|----------|
| 04 / 08 | CloudKit `recoveryURL: nil` → in-memory fallback, no delete/recreate | `PlayerSaveStoreConfiguration.resolveConfiguration` CloudKit branch | Live CloudKit still gated by CloudKitPreShipChecklist; needs a recoverable local URL plus a non-network test | 2026-08-19 |
| 04 / 08 | `deleteStoreOnFailure: true` wipes progress on any open failure | `PlayerSaveStore.openContainer` | Availability-over-durability product policy; needs SchemaMigrationPlan + backup-before-delete | 2026-08-19 |
| 13 | Full `PlayerSave` snapshot on every `performBatchMutation` | `PlayerSaveStore.performBatchMutation` `SnapshotProjection` | High-risk rewrite; measure Instruments first | 2026-08-19 |

## Rejected proposals

Do not re-propose without new evidence beyond the recorded reason.

| Owning audit | Proposal | Rejection reason | Decided |
|--------------|----------|------------------|---------|
| _none_ | | | |

## Accepted non-findings

Candidates confirmed as intentional or not worth fixing. Skip them during triage.

| Owning audit | Candidate | Why accepted | Decided |
|--------------|-----------|--------------|---------|
| 08 / 11 | `BattleRuntime` / `PlayBattleLaunch` | Intentional presentation/runtime and launch seams | 2026-08-05 |
| 08 | Options vs `PlayerSave`; catalog authored vs generated | Architecture hard-stop dual seams | 2026-08-05 |
| 08 / 11 | `TrinketFeatureAdapters` module split | Enforced package DAG boundary | 2026-08-05 |
| 08 | `PlayerSaveSanitizer` / labyrinth regeneration | Live save migration; consumer window open | 2026-08-05 |
| 11 | `StageSelectRowPresentation` stage/spire/labyrinth builders | Mode-specific field sources; shared config object would add ceremony | 2026-08-05 |
| 08 | `PlayerSave` / wire aspects decode, ability-ID remaps | Live save consumer window still open; propose only after sunset | 2026-08-05 |
| 11 | `PlayModeGraph` / `LaunchRunCallbacks` | Documented Play assembly owner; not deferred-bind theater | 2026-08-05 |
| 11 | `check-build-cache-paths.sh` divergent path lists | Intentional CI vs local freshness differences; documented | 2026-08-05 |
| 08 | `KeywordShineBorder` vs `CombatantBuffAuraBorder` | Parallel shimmer, but buff aura uses `TrinketDesign.cardShape` (battle 3:4 identity) vs rounded keyword shine | 2026-08-17 |
| 01 | Stage-select placeholder SF Symbols using `Font.system(size:)` | Already `@ScaledMetric`; audit allowlist for decorative symbols | 2026-08-17 |
