# Persistence storage contract

Use with [persistence ownership](persistence.md) for schemas, graph reconciliation, sanitization and recovery.

## Schema and sanitization

The mutable SwiftData graph, its mappings, and its schema are not public API.
Game consumers use `PlayerSaveStore` commands and value projections, keeping
validation, economic receipts, recovery, and observation on the same write path.
Only the root fixture initializer and schema have package access for
`TrinketPersistenceTestSupport`; graph inspection tests use `@testable` access.
The [module boundary gate](../../Scripts/check-module-boundaries.sh) rejects
public graph declarations. Access-control changes preserve model names, stored
fields, relationships, and schema versions; they do not require a save migration.

Labyrinth node decoding clamps negative saved depth before cleared-boss exit
repair, which uses that depth to generate the next floor. Preserve the node's
identity, cleared state and readable payloads when repairing damaged scalars.
Readable grid coordinates outside the floor's bounded geometry use the existing
fallback before neighbor or map-projection arithmetic.

Reads share one complete in-memory save value with independently observed domain
sections and root fields. Views read the narrow section or `sessionGeneration`;
`currentSave` observes the complete transaction snapshot. `installObservedSave`
notifies affected readers before swapping that value, then completes their
notifications. Synchronous leading-edge observers see the complete previous commit,
including when reading another section; subsequent reads see the complete accepted
save. Unchanged sections do not invalidate their readers. Load, gameplay commits,
and full replacements use this same publication boundary.

Load/repair sanitizes `root.toPlayerSave()` from the SwiftData graph. `PlayerSave.currentSchemaVersion` versions the value-layer payload and its sanitizer/mapping migrations independently of the SwiftData migration version declared by `PlayerSaveSchema`; bumping one does not imply bumping the other. Slice writes expand through `PlayerSaveSlice.sanitizeTargets`: inventory also sanitizes roster (equipped items must exist), and labyrinth also sanitizes roster (recruit eligibility feeds map healing). Labyrinth sanitize runs on labyrinth mutations and full load, not on every inventory or roster write; recruit eligibility is applied when a map is generated.

Roster sanitization accepts current catalog IDs and applies [Core talent repair](../../Packages/TrinketCore/README.md).
Roster hydration maps retired `sap-arrow` selections to `bounty-shot` before
unknown-ID fallback, preserving the Stun-and-Gold choice in local and cloud saves. Rogue
Venom Fangs Skill selections migrate to Feint before fallback; other combatants
retain Venom Fangs. Both local save reads and cloud restoration use this mapping.

Inventory admission and repair share ownership keys: physical item ID, Trinket
template for Trinkets, and Unique template for Unique items. Repair retains the
first accepted item in save order; a rejected record reserves no other keys.
Normal equipment copies with distinct physical IDs remain valid.
Equipment repair reserves physical IDs only after slot admission, preserving a valid
secondary assignment when its earlier primary entry is invalid. Resolving shared
equipment ownership also rechecks dependent weapon pairs before publication.

Contracts decode independent fields separately: unreadable offers can regenerate
without erasing earned encounter levels or completion receipts, and a damaged
scalar does not discard otherwise readable pinned offers.

## Save compatibility

Distributed TestFlight builds have local player saves that must be preserved or
migrated when schemas or serialized identifiers change. Production CloudKit remains
gated by the [release checklist](../Platform/CloudKitPreShipChecklist.md).
Historical development-save migrations and retired identifier aliases were removed
before that distribution; their retirement is not permission to remove support for
current saves. The current value schema is 20. Distributed wire-18/19 graphs, recovery snapshots,
cloud ancestors and outbox snapshots/deltas migrate through the shared codec.
Older development schemas and future schemas are rejected without rewriting their
progress. SwiftData graph v3 is frozen, including all relationship inverses; graph
v4 adds optional Library history through a lightweight migration. Graph v4 is
also frozen; v5 adds optional inventory inscription positions and Homestead wish
template IDs through lightweight migration. Both additions decode absent in old
value snapshots. The value-version bump prevents older clients from dropping the
new metadata when re-saving a new snapshot. Item powers and inscription position travel together as one item
through cloud conflict selection; wish selection follows existing scalar branch
selection and clears against merged ownership. Unsupported Labyrinth map payloads use
the existing unreadable-map recovery path, without translating historical floor
progress. Current-data validation, relationship repair, and corruption recovery
remain required.

Labyrinth's map is a JSON blob (`LabyrinthProgressModel.mapPayload`) while roster/inventory/homestead are normalized child tables — intentional trade-off for spatial graph queries; don't normalize the labyrinth without measuring encode cost.

## Durable acceptance and recovery

A database write failure first preserves the complete candidate in an atomic
`.pending-save.json` file beside the store. The versioned local envelope uses the shared
`PlayerSaveSnapshot` value codec and includes local session generation and exact cloud
metadata. Recovery decodes local values before ordinary startup repair; it must not
use cloud admission, which rejects unreadable Labyrinth maps. Opaque unreadable map
bytes travel in an optional sidecar field so restoration into a replacement database
preserves them until local repair. Older sidecars without those bytes remain readable;
SwiftData and remote snapshot schemas are unchanged.
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
Any failure to restore it, including protected-file reads, unsupported versions,
outbox restoration, or preservation of the previous graph, refuses store opening
before startup repair or persistence retries. Keep the authoritative sidecar in
place for a later open. Persistence alone owns the memory fallback, retaining its
durable recovery path; the app must honor a refused open with its existing Retry
screen rather than constructing a fresh, unrelated memory store.
Reset replaces the prior pending record only when the fresh reset is durable;
a failed reset retains the prior recoverable progress. If cleanup after a durable
reset fails, startup keeps the newer graph and retries pending-file cleanup.
Previous snapshots are never restored automatically after reset. This does not
change the SwiftData or CloudKit schema.

Gameplay, cloud transitions and resets share `PlayerSaveStore.commitGraph` as
one durable publication boundary. `PlayerSaveGraphWrite` serializes selected map,
item-power, Contract and Voyage payloads before graph or outbox mutation. Encoding
failure rejects the transaction as invalid input; mappers cannot log and discard
payloads or terminate the process. Prepare cloud metadata and outbox additions
before mutating the graph; retain original graph payload bytes and removed outbox
rows for nonthrowing compensation.
Publish cloud state and observed save slices only after the graph or recovery file
accepts the candidate. Once the current candidate reaches the recovery file, a
later database failure retains that acceptance and retries only database persistence;
it must not attempt another fallible recovery write or replay the player action.
An older pending file alone does not prove acceptance of a new candidate.
A refused write restores affected graph slices, the exact
prior metadata bytes and graph/outbox payloads without re-encoding prior values.
Compensation stays unsaved until a later successful write; do not use
`ModelContext.rollback()` because restoring deleted relationship rows can crash
SwiftData on the iOS 27 simulator. Resets, including replacement of degraded
storage, require the primary database write before replacing prior recoverable
progress. There is no optimistic deferred-write path.
The boundary holds exclusive admission through diagnostics, durable writes and
observed-slice publication: synchronous observation callbacks cannot start a
second graph write, reset or cloud replacement midway through a commit. Such
attempts return a retryable storage failure. The commit revision advances after
publication, making candidates captured by leading-edge observers obsolete even
if retained until the commit returns.
Lifecycle and sync checkpoints retry pending recovery files without rolling back
already accepted progress. Reload tests prove subsequent writes retain the
recovered values.

`performSaveAction` runs the initial action and registers any retry within one
failure boundary. Persistence commands record failures in that attempt; the shared
Progress Status diagnostic never decides whether to start or continue a retry.
A later successful write cannot hide an earlier failure in the same attempt, and
an unrelated old error cannot turn a rejection into a queued action. Nested actions
own their failures and retries independently, so a failed reward does not replay
an already completed encounter-opening step. The retained closure receives `isRetry`
for delayed completion feedback; it must recheck its encounter or choice identity.
Keys identify replaceable player intents. Every submission takes ownership before
running its initial action and retires the previous callback with that key, even
when the new intent rejects or needs no write. Only the current submission may
schedule, continue, or finish its retry; a re-entrant replacement cannot be removed
by the old callback's completion. Different keys remain independent. The captured
session generation prevents late writes or navigation across reset/account boundaries.
An obsolete callback that performs no write ends its retry without hiding an unrelated
error. Interaction
owners retain only current choices/encounters while pending. Linked Homestead actions commit
locally and upload later; transient sync failures retry without player prompts.
Pending legacy server requests still reconcile and acknowledge their original
receipts after reload or a lost response. Current clients never initiate those
commands; Homestead uses the local transaction and journal path. Synchronization
coalesces callers onto one task and reports completion after durable acknowledgement.
Each waiter retires only its completed synchronization, so a completed task cannot
be reused for a newly enqueued request. Total device write refusal cannot guarantee
survival of an uncommitted action across process termination; do not report that
an action completed before a durable write succeeds.

Awaited Homestead commands (building, production collection, and forging) own
their retries inside Persistence. `retryingSaveTransaction` accepts only a
synchronous transaction attempt and uses its typed storage error; validation and
domain rejections terminate immediately. It captures session generation before
yielding for pending feedback and rechecks it before each attempt, so reset or
account replacement cannot interleave between that check and the commit. Views
await the command's terminal result and clear pending feedback on every outcome;
they do not supply retry predicates or infer purchase success from a changed tier.

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

Cloud synchronization separates CPU-bound value planning from main-actor store
work. `CloudSavePlanner` concurrently restores and merges snapshots, replays offline
actions, and prepares local transitions; only immutable `Sendable` values cross
that boundary. The coordinator retains transport ordering, presentation preparation,
and durable commits. It rechecks cancellation, account and pending-request identity
before upload, and transition source state before local publication. New gameplay
may extend a frozen upload prefix while planning runs; its later actions remain
pending until their own receipt. Replay checks cancellation between actions.
Exhausted revision counters, reset generations, or production authority sequences
reject synchronization before publication; clocks never wrap or stop advancing silently.

Approved reconciliation merges concurrent branches within the same reset epoch
without player conflict prompts. Each durable game mutation records an
identified domain action with reconstructible before/after snapshots in the local cloud outbox.
Upload requests
carry those actions, their acknowledged base snapshot, and a stable request ID;
the server replays the actions into one complete projected save and an immutable
receipt. A successful receipt removes only its included local actions, and only
when the fetched head's vector clock includes the receipted request. Head and
receipt reads may straddle a commit; an older head leaves the pending request and
journal intact for the next fetch instead of replacing earned progress. Union earned
items, unlocks, claims, and completion. Union talent purchases while honoring
removals from the shared base, so a talent reset survives unrelated progress;
unrelated saves without a shared base union talents. Use the latest valid party/loadout
edit, retaining displaced gear in Inventory. Reconcile ability selections per tier
against the shared base, treating an absent loadout as the catalog defaults, so
independent Basic and Skill edits survive together; conflicting edits to one tier
use the latest choice. A one-sided change to an existing item,
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
Current production commands always validate economic coverage, including an empty
receipt set for non-economic edits. Unrestricted snapshot-inferred writes are
Debug-only fixture APIs, preserving legacy replay coverage without a gameplay bypass.
Preserve older journal readers rather than reconstructing
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
while local play continues. Immutable in-memory history shares prefixes through balanced record blocks.
Replay, receipt inspection, equality and journal coding stream those blocks without
flattening the full action history into temporary arrays; iteration keeps only a
logarithmic traversal stack, so replay can check cancellation between actions.
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
Compare sanitized incoming progress with the current domain value; timestamp-only
updates and repairs that leave the accepted domain unchanged preserve the session.
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

## Library history

Library persists a separate optional root payload and independently observed slice.
Its version-one value holds encountered/defeated enemy sets, completed project IDs,
learned recipe IDs and a backfill version. Unknown IDs remain inert and round-trip;
unknown or damaged payload bytes remain opaque and disable dependent activities.
Standard crafting and ordinary play remain available. Reset follows the existing
save generation and cloud epoch, never a parallel reset mechanism.

The source-owned legacy mapping freezes provable wire-18 Campaign/Spire enemies;
retained cleared spatial nodes supply explicit enemy IDs. No inference comes from
current random offers or current catalogs. Backfill never queues celebrations.
Current companion, Library-tier and Spire changes evaluate a small pure project
catalog in the same candidate as the triggering write. Wallet and selection-only
changes do not reevaluate it. Readable same-epoch cloud histories merge by union.
[Library](../Product/Library.md) owns player-facing unlock and discovery rules.
