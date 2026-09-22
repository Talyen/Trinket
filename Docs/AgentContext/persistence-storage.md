# Persistence storage contract

Use with [persistence ownership](persistence.md) for schemas, graph reconciliation, sanitization and recovery.

Reads use an in-memory observed projection; load/repair sanitizes `root.toPlayerSave()` from the SwiftData graph. `PlayerSave.currentSchemaVersion` versions the value-layer payload and its sanitizer/mapping migrations independently of the SwiftData migration version declared by `PlayerSaveSchema`; bumping one does not imply bumping the other. Slice writes expand through `PlayerSaveSlice.sanitizeTargets`: inventory also sanitizes roster (equipped items must exist), and labyrinth also sanitizes roster (recruit eligibility feeds map healing). Labyrinth sanitize runs on labyrinth mutations and full load, not on every inventory or roster write; recruit eligibility is applied when a map is generated.

Roster sanitization accepts current catalog IDs and applies [Core talent repair](../../Packages/TrinketCore/README.md).
Roster hydration maps retired `sap-arrow` selections to `bounty-shot` before
unknown-ID fallback, preserving the Stun-and-Gold choice in local and cloud saves.

Distributed TestFlight builds have local player saves that must be preserved or
migrated when schemas or serialized identifiers change. Production CloudKit remains
gated by the [release checklist](../Platform/CloudKitPreShipChecklist.md).
Historical development-save migrations and retired identifier aliases were removed
before that distribution; their retirement is not permission to remove support for
current saves. The current value schema identifier is unchanged. Unsupported value
schemas are rejected without rewriting their progress. Unsupported Labyrinth map payloads use
the existing unreadable-map recovery path, without translating historical floor
progress. Current-data validation, relationship repair, and corruption recovery
remain required.

Labyrinth's map is a JSON blob (`LabyrinthProgressModel.mapPayload`) while roster/inventory/homestead are normalized child tables — intentional trade-off for spatial graph queries; don't normalize the labyrinth without measuring encode cost.

A database write failure first preserves the complete candidate in an atomic
`.pending-save.json` file beside the store. The versioned local envelope reuses
`CloudSaveSnapshot` and includes local session generation and exact cloud metadata.
A pending recovery record is authoritative: subsequent writes update it before the
primary graph, so account switches, resets, receipts, and gameplay cannot separate.
Successful graph persistence removes the pending record. Recovery retries use
bounded backoff while the app runs. Startup restores the pending record before
publishing state and preserves the previous readable graph snapshot separately.
An unreadable recovery record is not discarded or replaced with older progress.
Reset replaces the prior pending record only when the fresh reset is durable;
a failed reset retains the prior recoverable progress. Previous snapshots are
never restored automatically after reset. This does not change the SwiftData or CloudKit schema.

An action completes only after the graph or recovery file accepts its save. If
both writes fail, restore the pre-mutation value snapshot into affected graph
slices and the observed projection. Compensation stays unsaved until a later
successful write; do not use `ModelContext.rollback()` because restoring deleted
relationship rows can crash SwiftData on the iOS 27 simulator. An immediate total
failure preserves earlier deferred changes; a failed explicit deferred flush
restores its last persisted snapshot. Reload tests prove subsequent writes retain
the recovered values. Production actions use immediate commits.

`retrySaveAction` retains a failed action and retries it without a player prompt.
Keys prevent duplicate retries; the captured session generation prevents late
writes or navigation across reset/account boundaries. Interaction owners retain
only current choices/encounters while pending. Transient cloud production failures
use the same silent retry policy with asynchronous operations; server authority
and receipt rules remain unchanged. Total device write refusal cannot guarantee
survival of an uncommitted action across process termination; do not report that
an action completed before a durable write succeeds.

## CloudKit preparation

SwiftData always opens the local graph at its existing URL with CloudKit mirroring
set to `.none`. `PlayerSaveCloudSync` and `CloudKitSaveTransport`, owned by
Persistence, exchange versioned complete snapshots in the existing private
container. The authored `CLOUDKIT_SYNC_ENABLED` build setting defaults to `NO`;
an explicitly enabled build requests automatic sync through its Info.plist value.
Debug also supports an opt-in retained until disabled; Release ignores that
development argument/preference. Test, reset, named, explicit-URL, and in-memory
public configurations stay isolated even in a cloud-enabled build.

`PlayerSaveRoot.cloudStatePayload` is optional local metadata: device revision
clock, active account, last acknowledged head, pending request, reset intent,
account archives, and first-attachment/guest backup. Account keys include container
and CloudKit environment so Development state cannot be mistaken for Production state. It is committed with the
same graph transaction. The payload is never uploaded wholesale; cloud snapshots
contain only the active game's values. Invalid sync metadata is retained while
sync is disabled and local play continues. Store-open failure preserves the
original files and retains accepted new progress in the recovery file; only an
explicit reset may delete the store. The confirmed Reset Game Progress action reopens durable storage and
commits a fresh save before replacing the memory-only session. A failed recovery
keeps that session available for retry. Do not restore automatic delete-and-recreate
recovery during migration.

Approved reconciliation selects a complete save without player conflict prompts.
Within the same reset epoch and production-authority sequence, prefer causal
continuation using device revision clocks, then furthest Campaign completion,
then most recent play and a stable revision-ID tie-breaker. A fresh installation
cannot displace populated progress. Archive conflicting progress in the same
atomic server operation before installing the selected snapshot. A failed archive
leaves the local snapshot and outbox intact. Currency, materials, reward claims,
inventory/equipment, recruitment/talents, Campaign, Spires, Labyrinth, Contracts,
and Homestead upgrades remain coherent; never sum independent balances.

The server's Homestead cursor and pending production are authoritative across
branch selection. A snapshot predating a committed production claim or upgrade
is archived rather than allowed to undo that operation, even if its Campaign rank
is higher. Some offline play can therefore remain only in its recovery backup.
[Progression](persistence-progression.md) owns the claim transaction.

Reset advances the server epoch and invalidates older progress and claims.
Concurrent stale reset requests cannot wipe a newer epoch. Backups from older
epochs are never automatically restored. Signing out keeps a local copy and an
account archive. Further signed-out play stays separate; returning to an account
restores its own archive/cloud head, retaining the guest copy locally. Switching
accounts never uploads the previous account's progress into the new account.
If a cloud-disabled rollback build performs local production, it first archives
and detaches the linked account. That local session remains a guest backup when
cloud play resumes, preventing an offline claim from reopening a server interval.

Late asynchronous results compare their captured snapshot with current local
values. New local mutations are reconciled in a later request; receipt recovery
cannot acknowledge unseen remote changes as ancestors of those mutations.
Adopting external progress increments the device-local session generation and
invokes AppState's transient-session invalidation. Starter navigation also follows
that generation so an imported hero choice refreshes the companion step.
Acknowledging this device's own upload or claim does not end its current session. Session generation is local
coordination state and is excluded from cloud snapshot coding.

These contracts have isolated test coverage. Real provisioning, schema, upgrade,
rollback, account, and two-device evidence remain the
[CloudKit release gates](../Platform/CloudKitPreShipChecklist.md).

Voyage persists a versioned optional `voyagePayload` on the root and in complete-save snapshots. Missing data initializes an empty board; unreadable active-route data is retained verbatim. The Voyage slice participates in change detection, publication, recovery, and reset. See [Voyage](../Product/Voyage.md#persistence).
