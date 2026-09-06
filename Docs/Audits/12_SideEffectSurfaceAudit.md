# 12. Side-Effect Surface Audit

**Goal:** Keep nondeterminism, I/O, and shared mutation under clear owners with
appropriate initiation, lifetime, ordering, and failure contracts.

Use the [shared audit contract](README.md) for scope, evidence, severity, and sizing.
[Architecture](../Platform/Architecture.md) owns module boundaries; consult
[persistence context](../AgentContext/persistence.md),
[audio context](../AgentContext/audio.md), and
[BattleFeature](../../Packages/TrinketBattleFeature/README.md) for their effect seams.

## Domain invariants

- Battle rule outcomes use injected RNG, not wall-clock or unseeded entropy.
  Session/presentation identifiers and tooling timestamps are distinct from rule
  entropy; judge use and target, not a package-wide match for `UUID` or `Date`.
- Save writes and synchronization follow the persistence owner; options storage
  remains distinct from player-save policy. A caller legitimately initiating an
  owned effect is not itself an ownership leak.
- Audio playback remains under its audio owner; catalog-backed Ultimate cinematic
  playback belongs to Battle presentation. Do not misclassify video as an audio leak.
  Non-fatal audio failure handling may be intentional; follow its existing contract
  rather than converting a best-effort effect into a crash.
- Decorative randomness must have stable identity over the intended presentation
  lifetime rather than changing accidentally on view evaluation.
- Effects must not duplicate, outlive their purpose, or reorder observable state
  because initiation/retry/termination is unowned. Cancellation and failures follow
  the boundary's contract; not every effect requires user-facing error UI.
- Absence of direct CloudKit calls does not imply missing OS-managed SwiftData sync.
  Release readiness belongs to the
  [CloudKit checklist](../Platform/CloudKitPreShipChecklist.md).

## Evidence and success

Show a violated canonical ownership boundary or a reachable duplication, ordering,
lifetime, determinism, or failure-handling defect. An effect primitive's presence
alone is insufficient. Where an existing legitimate seam is missing from guidance,
repair the canonical documentation rather than inventing another allowlist here.
A genuinely new boundary follows the shared proposal policy.

Restore the effect's contract and verify relevant observable behavior. Transaction
outcomes belong to [03](03_BehaviorHardeningAudit.md); actor/executor, reentrancy,
and concurrent task-lifetime hazards belong to
[14](14_SwiftConcurrencyDataRaceAudit.md). Keep one finding per root cause.
