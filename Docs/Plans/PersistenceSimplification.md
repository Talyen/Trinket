---
type: execution-plan
status: blocked
reason: Awaiting the exceptional player-visible startup outcome decision
created: 2026-09-10
updated: 2026-09-11
expires: 2026-09-24
---

# Preserve saves and simplify storage recovery

## Status and completed work

The approved cleanup and bounded prevention check are complete. Remaining startup
work is blocked on the player-visible decision below. This documentation update
does not approve or implement that behavior.

The cleanup fix appends SQLite's `-wal`, `-shm`, and `-journal` suffixes to the
complete store filename. It preserves unrelated siblings and handles extensionless
paths. Sentinel-file coverage replaced unnecessary SwiftData setup while retaining
reset and reload proofs. The implementation handoff recorded 260 passing Persistence
tests and its routed checks; that is historical validation, not a new run here.

## Confirmed evidence

- [ModelContainerBootstrap](../../Packages/TrinketPersistence/Sources/TrinketPersistence/ModelContainerBootstrap.swift)
  catches primary-open failures and can delete/recreate the store without classifying
  corruption. `PlayerSaveStore.openSaveContainer` enables that branch. A non-corrupt
  open failure could therefore destroy recoverable progress; no real-device loss
  or save-open failure was reproduced.
- [TrinketApp](../../Trinket/App/TrinketApp.swift) also retries failed bootstrap
  with an explicit in-memory store. Removing only the package fallback would leave
  this second path able to conceal a storage failure.
- The prevention check found no basis for a general recovery framework, protected-data
  observer, replacement database, or backup system. Current schema support and
  failure compensation follow the [storage contract](../AgentContext/persistence-storage.md).
  Deferred writes are explicit batch operations under the
  [persistence contract](../AgentContext/persistence.md), not a launch-argument mode.
- Sampled battle and Shop completion paths wait for successful persistence.
  Existing coverage exercises failed writes, retry, and reload. No additional
  action-transaction defect was established by that check.

The product goal is to prevent failures and recover proven recoverable conditions
without asking players to diagnose storage or reinstall. Fresh in-memory play,
silent resets, and permanent stalls are not successful recovery. No framework can
guarantee durable writes while storage remains unavailable.

## Remaining startup decision

Proposed outcome: when the real save cannot open, preserve it and show the existing
native unavailable layout with **“Trinket can’t open right now.”** Do not expose
technical details, a reset action, troubleshooting instructions, acknowledgement
alerts, or a spinner. A subsequent launch retries the untouched save.

The unresolved tradeoff is that play is unavailable during this condition. A
permanent schema/storage problem may need an app update or an external condition
to change. Approval is specifically for that exceptional player-visible outcome;
no invisible repair or perpetual availability is promised.

## Implementation after that decision

1. Open the configured SwiftData container or throw. Remove automatic deletion
   and both implicit in-memory fallback layers together. Keep explicit in-memory
   stores for previews/tests and intentional test launch options.
2. Delete the bootstrap wrapper if only one construction call remains. Move
   explicit reset cleanup to `PlayerSaveStoreConfiguration`, preserving its fixed
   filename behavior. Remove unused recovery parameters, flags, and acknowledgement
   UI; add no public startup abstraction or backend protocol.
3. Treat failed initial-root creation and required startup repair saves as failed
   startup. Keep the unavailable state in the existing app entry. Preserve runtime
   write compensation and meaningful action-failure reporting.
4. Replace wipe-policy coverage with invalid-store preservation: opening throws,
   original bytes survive, and no replacement game appears. Retain current-schema
   reload/reset coverage. Add a narrow internal test seam only for a consequential
   failure that existing temporary-store fixtures cannot exercise.
5. Reroute all affected paths under [Verification](../Platform/Verification.md),
   including Persistence/AppState tests, app compilation, and targeted launch smoke.
   Inspect the exceptional screen through an isolated fixture, never a real save;
   preserve launch artwork pins.

Do not add polling, protected-data handling, migration stages, or backups without
specific evidence that the supported failure requires them. CloudKit remains gated
by its [release checklist](../Platform/CloudKitPreShipChecklist.md).

## Completion

Keep this plan until the startup outcome is decided and any approved work is
verified, or the remaining proposal is explicitly cancelled. Then fold durable
rules into their owners and archive the outcome under [Plans](README.md).
