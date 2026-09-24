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
A pending recovery record is authoritative unless the primary graph has a newer
local session generation from a durable reset. Subsequent writes update a
pending record before the primary graph, so account switches, resets, receipts,
and gameplay cannot separate.
Successful graph persistence removes the pending record. Recovery retries use
bounded backoff while the app runs. Startup restores the pending record before
publishing state and preserves the previous readable graph snapshot separately.
An unreadable recovery record is not discarded or replaced with older progress.
Reset replaces the prior pending record only when the fresh reset is durable;
a failed reset retains the prior recoverable progress. If cleanup after a durable
reset fails, startup keeps the newer graph and retries pending-file cleanup.
Previous snapshots are never restored automatically after reset. This does not
change the SwiftData or CloudKit schema.

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
only current choices/encounters while pending. Linked Homestead actions commit
locally and upload later; transient sync failures retry without player prompts.
Pending legacy server receipts remain replay-safe. Total device write refusal cannot guarantee
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

Approved reconciliation merges concurrent branches within the same reset epoch
without player conflict prompts. Each immediate durable game mutation records an
identified domain action with before/after snapshots in the local cloud outbox;
deferred mutations remain in the complete save projection. Upload requests
carry those actions, their acknowledged base snapshot, and a stable request ID;
the server replays the actions into one complete projected save and an immutable
receipt. A successful receipt removes only its included local actions. Union earned
items, unlocks, talents, claims, and completion; use the latest valid party/loadout
edit, retaining displaced gear in Inventory. A one-sided change to an existing item,
including corruption or salvage, survives unrelated progress on the other branch.
An abandoned or dismissed Voyage must not be restored from stale route progress.
Labyrinth floor reconciliation carries clusters and boss exits with nodes so the
next floor stays reachable. Merge Shop purchase markers only for the same pinned
item and price; use a readable stock copy when its preferred peer is unreadable.
Preserve a Mystery event pinned on either Labyrinth or Voyage branch, and use a
readable offer snapshot when the preferred copy is damaged. Reconcile Contract
offers by difficulty against the shared base so a completed offer cannot return
after an unrelated action on another device. A one-sided completed Mystery also
advances the corruption altar cooldown across the merge.
Combine independent balance changes from a shared base and floor concurrent
overspending at zero. On first attachment of unrelated older saves, take the larger
balance per resource. Archive conflicting snapshots in the same atomic server
operation before installing the merge. A failed archive leaves
the local snapshot and outbox intact.

Long offline journals compact older, unsubmitted adjacent actions into one
identified transition while retaining recent actions and any actions already in
a pending request. The compacted transition keeps its first before-snapshot and
last after-snapshot; a receipt removes only the actions it actually submitted.

The merged Homestead cursor cannot move backward. Overlapping collections of the
same production interval count once; distinct upgrades persist, and a shortage
from concurrent spending is forgiven at zero balance. Pending legacy production
receipts remain recoverable after a lost response.
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
An app-provided preparation hook may await incoming presentation resources before
the external save is durably installed; a cancelled or stale preparation must
leave the observed save and cloud request intact. [UI performance](ui-performance.md)
owns the artwork pin handoff.
Acknowledging this device's own upload or claim does not end its current session. Session generation is local
coordination state and is excluded from cloud snapshot coding.

These contracts have isolated test coverage. Real provisioning, schema, upgrade,
rollback, account, and two-device evidence remain the
[CloudKit release gates](../Platform/CloudKitPreShipChecklist.md).

Voyage persists a versioned optional `voyagePayload` on the root and in complete-save snapshots. Missing data initializes an empty board; unreadable active-route data is retained verbatim. The Voyage slice participates in change detection, publication, recovery, and reset. See [Voyage](../Product/Voyage.md#persistence).
