# Persistence storage contract

Use with [persistence ownership](persistence.md) for schemas, graph reconciliation, sanitization and recovery.

## Schema and sanitization

Labyrinth node decoding clamps negative saved depth before cleared-boss exit
repair, which uses that depth to generate the next floor. Preserve the node's
identity, cleared state and readable payloads when repairing damaged scalars.

Reads use an in-memory observed projection; load/repair sanitizes `root.toPlayerSave()` from the SwiftData graph. `PlayerSave.currentSchemaVersion` versions the value-layer payload and its sanitizer/mapping migrations independently of the SwiftData migration version declared by `PlayerSaveSchema`; bumping one does not imply bumping the other. Slice writes expand through `PlayerSaveSlice.sanitizeTargets`: inventory also sanitizes roster (equipped items must exist), and labyrinth also sanitizes roster (recruit eligibility feeds map healing). Labyrinth sanitize runs on labyrinth mutations and full load, not on every inventory or roster write; recruit eligibility is applied when a map is generated.

Roster sanitization accepts current catalog IDs and applies [Core talent repair](../../Packages/TrinketCore/README.md).
Roster hydration maps retired `sap-arrow` selections to `bounty-shot` before
unknown-ID fallback, preserving the Stun-and-Gold choice in local and cloud saves. Rogue
Venom Fangs Skill selections migrate to Feint before fallback; other combatants
retain Venom Fangs. Both local save reads and cloud restoration use this mapping.

Inventory admission and repair share ownership keys: physical item ID, Trinket
template for Trinkets, and Unique template for Unique items. Repair retains the
first accepted item in save order; a rejected record reserves no other keys.
Normal equipment copies with distinct physical IDs remain valid.

Contracts decode independent fields separately: unreadable offers can regenerate
without erasing earned encounter levels or completion receipts, and a damaged
scalar does not discard otherwise readable pinned offers.

## Save compatibility

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

## Durable acceptance and recovery

A database write failure first preserves the complete candidate in an atomic
`.pending-save.json` file beside the store. The versioned local envelope reuses
`CloudSaveSnapshot` and includes local session generation and exact cloud metadata.
New recovery records also carry the referenced outbox row payloads; older records
remain readable. Restore those rows with the save before resolving journal references.
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
writes or navigation across reset/account boundaries. The retry queue uses failures
recorded by persistence commands within each synchronous attempt; it does not
clear or use the shared Progress Status diagnostic to decide whether to continue.
An obsolete callback that performs no write ends its retry without hiding an
unrelated error. Interaction owners retain
only current choices/encounters while pending. Linked Homestead actions commit
locally and upload later; transient sync failures retry without player prompts.
Pending legacy server receipts remain replay-safe. Total device write refusal cannot guarantee
survival of an uncommitted action across process termination; do not report that
an action completed before a durable write succeeds.

## CloudKit preparation

### Local sync configuration

SwiftData always opens the local graph at its existing URL with CloudKit mirroring
set to `.none`. `PlayerSaveCloudSync` and `CloudKitSaveTransport`, owned by
Persistence, exchange versioned complete snapshots in the existing private
container. Device account, request and receipt transitions are computed without
side effects in `CloudSaveTransitions`; `PlayerSaveCloudSync` owns network work and
applies those plans through one preparation, stale-state check and durable commit
path. The authored `CLOUDKIT_SYNC_ENABLED` build setting defaults to `NO`;
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

### Reconciliation

Approved reconciliation merges concurrent branches within the same reset epoch
without player conflict prompts. Each immediate durable game mutation records an
identified domain action with reconstructible before/after snapshots in the local cloud outbox;
deferred mutations remain in the complete save projection. Upload requests
carry those actions, their acknowledged base snapshot, and a stable request ID;
the server replays the actions into one complete projected save and an immutable
receipt. A successful receipt removes only its included local actions. Union earned
items, unlocks, claims, and completion. Union talent purchases while honoring
removals from the shared base, so a talent reset survives unrelated progress;
unrelated saves without a shared base union talents. Use the latest valid party/loadout
edit, retaining displaced gear in Inventory. A one-sided change to an existing item,
including corruption or salvage, survives unrelated progress on the other branch.
Restoring a newer valid weapon pair reclaims its primary from an older assignment
on another combatant before enforcing unique equipped items.
For a shared physical item, salvage on either branch retires the item even if
the other branch corrupted it; the merged save cannot retain both gear and its materials.
New recruits use initial progression as the shared baseline when independent XP
awards arrive before that baseline has a roster row.
An abandoned or dismissed Voyage must not be restored from stale route progress.
Labyrinth floor reconciliation carries clusters and boss exits with nodes so the
next floor stays reachable. Merge Shop purchase markers and deduplicate charges only for the same pinned
item and price; use a readable stock copy when its preferred peer is unreadable.
Preserve a Mystery event pinned on either Labyrinth or Voyage branch, and use a
readable offer snapshot when the preferred copy is damaged. Reconcile Contract
offers by difficulty against the shared base so a completed offer cannot return
after an unrelated action on another device. Contract completion receipts distinguish
victory from board refresh, so two refreshes do not suppress independent rewards
once their shared base tracks claims. Older peers retain conservative overlap detection.
Completed Voyage run receipts survive route removal and deduplicate terminal payouts.
Completion and separate abandonment history prevent stale routes from reopening
without an embarked shared base.
Voyage board preparation replaces retired destinations, retaining unaffected offers.
Overlap detection checks both active runs when one device has started another Voyage.
Abandonment records no victory receipt. Both retirement histories use optional
payload fields that preserve older saves; retired older routes without receipts
cannot reconstruct their terminal claims.
Voyage decoding validates a completed route before normalizing it away, retaining
malformed payload bytes through the unreadable-state path. Independent Mystery
completions combine their corruption altar cooldown reductions; duplicate completions count once
even when the devices chose different rewards. A newly completed pinned altar preserves
its reset when its cooldown equals the shared base, including on a Labyrinth map
created after that base. Shared Voyage encounters retain the
larger earned total per resource for the final completion bonus.
Combine independent balance changes from a shared base and floor concurrent
overspending at zero. A resource changed on only one branch retains that change
even when another shared action disables reward combination. On first attachment of unrelated older saves, take the larger
balance per resource. Archive conflicting snapshots in the same atomic server
operation before installing the merge. A failed archive leaves
the local snapshot and outbox intact.

Offline journals retain each durable mutation's identity, ordering, and committed
effects using a checkpoint and lossless snapshot-field deltas. A receipt removes only the actions it actually submitted;
pending-request retries and reloads retain those same identities. Do not collapse
separate payouts into one snapshot pair: duplicate-claim detection would then
suppress unrelated earnings in the collapsed batch.

Battle rewards (including defeat XP), Salvage, Shop purchases, Homestead,
Mystery choices and Blacksmith forging supply version-one `SaveEconomicReceipt`
values inside Persistence-owned commands. Receipt-emitting appliers require the
synchronous transaction collector; there is no default that silently discards effects. Each receipt records the
actual committed currency, materials, XP, and fractional effects plus its claim
identity, pinned item/price, or installed building tier. Composite transactions
retain each receipt separately. Receipt-backed replay skips snapshot economic
inference and applies only effects whose claims have not already been accepted;
non-economic fields retain their snapshot reconciliation. Mystery records its choice
and encounter completion as one receipt under the same claim. Commit checks full
economic coverage before saving or journaling, so partial receipts cannot suppress
unrecorded earnings during replay. Shop charges deduplicate
only for matching pinned offers. Salvage retirement survives purchase-and-salvage
in one transaction, where the starting Inventory has no item row.

Homestead collections record pending credit, its production context, and per-resource
consumption coordinates within the reset epoch. The remote head unions consumed
ranges, including gaps from out-of-order uploads; overlapping collections pay only
the uncovered quantities. Local metadata caches the next coordinates so a gameplay
write never scans accumulated history. Action snapshots record the coordinates
already consumed locally, preventing stale pending credit from returning through
an unrelated reward. Spending does not alter these collection identities.

Older records retain their version-one economic or conservative snapshot replay,
including historically compacted records whose separate actions cannot be recovered.
Legacy generic batches retain that fallback. Current production economic commands
record explicit effects; non-economic commands and internal test fixtures may use
save-only batches. Preserve older journal readers rather than reconstructing
receipts whose separate actions are no longer recoverable. Unsupported
receipt/economic versions reject the entire upload before acknowledging or changing
progress. Local device metadata advances to version 3 when receipts are recorded;
new readers also accept versions 1 and 2. Receipt-backed remote heads use version 2;
new readers accept version 1, while older writers reject the newer head. This protects
receipt identities from downgrade writes without changing the player-save value or
SwiftData graph schema.

`CloudOutboxRecord` stores checkpoint and action payloads as independent local
SwiftData rows. Schema 3 adds this entity through a lightweight migration from the
unchanged schema-2 graph; the player-value and remote snapshot schemas are unchanged.
Preserve that schema-2 model shape when making future graph migrations.
Device metadata reads version-one legacy arrays without inferring missing
economic effects or changing action/request identities. Gameplay and outbox changes share one durable
commit or recovery record, including compensation after a refused write.

Save metadata carries journal IDs and prefix lengths, so new actions append rows
without encoding or copying accumulated history. Pending requests freeze a prefix;
account archives and pending requests retain their referenced rows. A receipt
rebases only remaining actions and prunes unreferenced rows in the same transaction.
Missing or unreadable referenced rows disable sync and preserve opaque metadata
while local play continues. Immutable in-memory history also shares prefixes.
Reconciliation restores snapshot inputs and explicit receipts one action at a time;
the approved concurrent-spending and selection policies remain unchanged. Changed snapshot fields are stored as
replacement values; a Gold edit does not repeat Inventory or Labyrinth maps.
Recovery-file writes serialize the complete compact outbox to remain self-contained.
Distribution remains disabled; CI owns reload, interrupted-request and long-offline
scaling checks, with device write-cost measurements required before wider enablement.

The merged Homestead cursor cannot move backward. Compare pending production at
that shared cursor so an earlier collection retains production earned afterward.
Only resources with a producer or retained production credit qualify for
production deduplication; unrelated earned Gold and materials still combine.
Overlapping collections count once, including after their resources are spent.
For legacy snapshot records, with unchanged producers and uncapped Gold
production, infer collections from pending credit at a shared cursor rather than
wallet growth; capped Gold retains conservative overlap handling. Shared building tiers
charge their authored cost once; distinct upgrades retain their separate costs.
Upgrades persist, and a shortage from concurrent spending is forgiven at zero
balance. Pending legacy production
receipts remain recoverable after a lost response.
[Progression](persistence-progression.md) owns the claim transaction.

### Reset and account isolation

Reset advances the server epoch and invalidates older progress and claims.
Concurrent stale reset requests cannot wipe a newer epoch. Backups from older
epochs are never automatically restored. Signing out keeps a local copy and an
account archive. Further signed-out play stays separate; returning to an account
restores its own archive/cloud head, retaining the guest copy locally. Switching
accounts never uploads the previous account's progress into the new account.
If a cloud-disabled rollback build performs local production, it first archives
and detaches the linked account. That local session remains a guest backup when
cloud play resumes, preventing an offline claim from reopening a server interval.

### External-save publication

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

### Release evidence

These contracts have isolated test coverage. Real provisioning, schema, upgrade,
rollback, account, and two-device evidence remain the
[CloudKit release gates](../Platform/CloudKitPreShipChecklist.md).

## Voyage payload

Voyage persists a versioned optional `voyagePayload` on the root and in complete-save snapshots. Missing data initializes an empty board; unreadable active-route data is retained verbatim. The Voyage slice participates in change detection, publication, recovery, and reset. See [Voyage](../Product/Voyage.md#persistence).
