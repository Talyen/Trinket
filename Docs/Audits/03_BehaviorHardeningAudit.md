# 03. Persistence, Synchronization & Transition Integrity Audit

**Goal:** Preserve player progress and coherent transactions across mutation,
persistence, recovery, synchronization, and lifecycle transitions.

Use the [shared audit contract](README.md) for evidence, severity, and sizing.
[Persistence context](../AgentContext/persistence.md) and
[TrinketPersistence](../../Packages/TrinketPersistence/README.md) own the save graph,
write policy, sanitizer, and recovery contracts.

## What to investigate

Follow consequential transitions such as rewards, currency/inventory changes,
crafting, encounter completion, load/migration, and retry through validation,
in-memory updates, durable storage, and player-visible completion. Look for
partial application, duplicate grants, stale writes, lost failures, and recovery
that destroys or misrepresents existing progress.

## Invariants

- Repeated actions and retries preserve the transaction's intended atomicity and
  idempotency. A disabled control alone does not establish durable integrity.
- Validation, sanitization, metadata, deferred writes, and rollback follow the
  persistence owner. Confirm whether a mutation actually bypasses those guarantees
  before adding another guard or timestamp update.
- Failures remain observable through the existing error/recovery contract. A log
  does not make lost progress acceptable, and a successful in-memory mutation is
  not proof that a save survived reload.
- Distinguish first-run absence, corrupt/unsupported data, and transient opening or
  writing failures. Default/in-memory recovery is acceptable only under the intended
  recovery policy; it must not silently overwrite recoverable progress or present
  temporary state as durable success.
- Preserve live save/schema compatibility and local play without iCloud under
  [product decisions](../Product/Decisions.md). Changes to destructive recovery or
  availability-versus-durability policy require the relevant product decision.

## Evidence and success

Establish a reachable violating transition, source-proven silent loss, or reproduction
of corruption, duplicate application, ordering failure, or misleading recovery.
Verify the complete repaired path, including reload/retry where it establishes the
invariant, using the cheapest existing semantic test owner under
[Testing.md](../Platform/Testing.md).

Audio handling belongs to [12](12_SideEffectSurfaceAudit.md); isolation hazards
belong to [14](14_SwiftConcurrencyDataRaceAudit.md). Necessary cross-owner repairs
remain part of one root-cause finding.
