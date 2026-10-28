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
An entered current-format map with a damaged entrance reconnects its retained
first-floor entry; repair preserves rooms, progress and pinned rewards.

Reads share one complete in-memory save value with independently observed domain
sections and root fields. Views read the narrow section or `sessionGeneration`;
`currentSave` observes the complete transaction snapshot. `installObservedSave`
notifies affected readers before swapping that value, then completes their
notifications. Synchronous leading-edge observers see the complete previous commit,
including when reading another section; subsequent reads see the complete accepted
save. Unchanged sections do not invalidate their readers. Load, gameplay commits,
and full replacements use this same publication boundary.
Graph mutations reconcile changed slices while preserving retained child-row
identities.

Load/repair sanitizes `root.toPlayerSave()` from the SwiftData graph. `PlayerSave.currentSchemaVersion` versions the value-layer payload and its sanitizer/mapping migrations independently of the SwiftData migration version declared by `PlayerSaveSchema`; bumping one does not imply bumping the other. Slice writes expand through `PlayerSaveSlice.sanitizeTargets`: inventory also sanitizes roster (equipped items must exist) and homestead, homestead also sanitizes library (building upgrades reconcile research tiers), and labyrinth also sanitizes roster (recruit eligibility feeds map healing). Labyrinth sanitize runs on labyrinth mutations and full load, not on every inventory or roster write; recruit eligibility is applied when a map is generated.

Roster sanitization accepts current catalog IDs and applies [Core talent repair](../../Packages/TrinketCore/README.md).
Progression repair uses Core's XP rollover rules after clamping invalid inputs;
Persistence retains the terminal-level XP clamp rather than duplicating leveling.
Duplicate progression rows retain the greatest repaired level/XP pair; duplicate
Spire rows retain the highest cleared floor before graph reconciliation removes them.
Roster hydration maps retired `sap-arrow` selections to `bounty-shot` before
unknown-ID fallback, preserving the Stun-and-Gold choice in local and cloud saves. Rogue
Venom Fangs Skill selections migrate to Feint before fallback; other combatants
retain Venom Fangs. Alchemist Mana Potion Skill selections migrate to Cinderbloom;
other combatants retain Mana Potion. Local save reads and cloud restoration use
these mappings.

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
Compatibility layers are versioned independently:

| Layer | Current format and retained compatibility | Executable owner |
|---|---|---|
| Player values | Write 20; migrate distributed wire 18/19 in graphs, recovery, cloud ancestors, and outbox snapshots/deltas. Reject older development and future schemas without rewriting progress. | [PlayerSave](../../Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSave.swift), [snapshot codec](../../Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveSnapshot.swift) |
| SwiftData graph | Lightweight 2 → 3 (outbox rows) → 4 (optional Library history) → 5 (optional inscription positions and Homestead wish IDs). Preserve historical model shapes and relationship inverses; v3/v4 are frozen. | [Migration plan](../../Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveGraph/PlayerSaveRoot.swift) |
| Journal | Action-backed journals use 2 with version-one action records; retain journal 1 and legacy metadata arrays. | [Journal codec](../../Packages/TrinketPersistence/Sources/TrinketPersistence/Cloud/CloudSaveJournal.swift) |
| Device metadata | Action-backed writes use 4; retain 1–3, including receipt-backed 3. | [CloudSaveState](../../Packages/TrinketPersistence/Sources/TrinketPersistence/Cloud/CloudSaveState.swift), [journal writer](../../Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore+CloudJournal.swift) |
| Remote head | Accepting actions advances to 3; retain 1 and receipt-backed 2. | [Reconciler](../../Packages/TrinketPersistence/Sources/TrinketPersistence/Cloud/CloudSaveReconciler.swift) |

Library and inscription/wish fields decode absent in older values. The value-version
bump prevents older clients from dropping new metadata on re-save; older readers
reject the newer journal/metadata/head formats rather than dropping action semantics.
Unsupported action, receipt, or economic versions reject the entire upload before
attachment, acknowledgement, or progress changes.

Item powers and inscription positions travel together through cloud conflict
selection. Wish selection follows scalar branch selection and clears against merged
ownership. Unsupported Labyrinth payloads follow unreadable-map recovery without
translating floor progress. Retain current-data validation, relationship repair, and
corruption recovery. Historical development migrations and aliases retired before
TestFlight distribution do not justify removing current-save compatibility.

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

`performSaveAction` runs the initial action and registers a retry from its returned
`SaveActionAttempt`: a product value plus that command's typed storage failure.
Commit and logging never record into an enclosing action. The shared Progress Status
diagnostic cannot decide whether to start or continue a retry. Mapping an attempt's
product value preserves its failure; terminating a stale intent returns an attempt
without failure. Multi-command workflows explicitly retain the unfinished step's
result, so a later successful write cannot hide its failure. Nested actions own
independent results/retries; a failed reward never replays a completed opening.
The retained closure receives `isRetry` for delayed feedback and rechecks its
encounter or choice identity.
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

Replay selects one explicit source per journal mutation: resolved actions, historical
receipts, historical economic deltas, or snapshot-only history. Absent and empty
receipt/action arrays are distinct. Action records cannot also supply receipts or
legacy economic deltas. Historical readers retain their original overlap policies.

[Journal replay](#journal-and-economic-replay) defines ownership for each admitted action.

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

#### Admission and receipts

Merge concurrent branches within an account without player conflict prompts.
Across reset epochs, merge snapshots conservatively rather than replaying old
economic or production receipts. Each durable mutation records an identified domain action with
reconstructible before/after snapshots in the local outbox. Uploads carry those
actions, their acknowledged base snapshot and a stable request ID; the server
replays them into one complete projected save and an immutable receipt.

Remove only receipted local actions, and only when the fetched head's vector clock
includes that request. Head and receipt reads may straddle a commit: an older head
leaves the pending request and journal intact for the next fetch. Archive conflicting
snapshots in the same atomic server operation before installing the merge; archive
failure preserves the local snapshot and outbox.

A request created during the current synchronization attempt has not yet been
sent, so its first upload need not look up a receipt. Every previously pending
request still checks for a receipt before retrying, including after a lost response.
CloudKit may read an existing head while preparing its zone and subscription;
preparation and account verification still finish before the head is accepted.

#### Snapshot merge rules

| Concern | Required result |
|---|---|
| Earned progress | Union earned items, unlocks, claims and completion. |
| Starter selection | Keep the furthest phase within an epoch; completed selection cannot reopen over an established roster. Same-phase Hero choices use recency. Explicit resets use reset authority. |
| Talents | Union purchases while honoring removals from the shared base, so reset survives unrelated progress. Unrelated saves without a shared base union talents. |
| Party and loadouts | Use the latest valid edit; keep displaced gear in Inventory. Merge ability selections per tier against the shared base, treating absent loadouts as catalog defaults. Independent Basic/Skill edits survive; conflicts within a tier use the latest choice. |
| Physical items | Preserve one-sided changes, including corruption or salvage. Restoring a newer valid weapon pair first reclaims its primary from older assignments, then enforces unique equipment. Salvage on either branch retires a shared item even if the other corrupted it; never retain both gear and its materials. |
| New recruits | Use initial progression as the shared baseline when independent XP arrives before a shared-base roster row exists. |
| Labyrinth | Carry clusters and boss exits with nodes so the next floor remains reachable. |
| Shop | Merge purchase markers; deduplicate charges only for the same pinned item and price. Fall back to a readable stock copy when the preferred peer is unreadable. |
| Mystery | Preserve events pinned on either Labyrinth/Voyage branch, using a readable offer when the preferred copy is damaged. Independent completions combine altar cooldown reductions; duplicates count once even with different rewards. A newly completed pinned altar preserves its reset when cooldown equals the shared base, including on a map created after that base. |
| Contracts | Merge offers by difficulty against the shared base so unrelated progress cannot resurrect a completed offer. Distinguish victory from refresh receipts: two refreshes cannot suppress independent rewards once the base tracks claims. Older peers retain conservative overlap detection. |
| Balances | Combine independent shared-base changes, including fractional reward carries, before applying capacity limits or flooring concurrent overspending at zero. Preserve a one-sided resource change even if another shared action disables reward combination. First attachment of unrelated older saves takes the larger balance per resource. |

#### Voyage merge rules

- Completion receipts survive route removal and deduplicate terminal payouts.
  Completion and separate abandonment history prevent stale routes reopening
  without an embarked shared base. An abandoned or dismissed Voyage cannot return
  from stale progress; abandonment records no victory receipt.
- Both retirement histories use optional fields compatible with older saves.
  Retired older routes without receipts cannot reconstruct terminal claims.
  Validate completed routes before normalizing them away; preserve malformed
  payload bytes through unreadable-state handling.
- Board preparation replaces retired destinations and retains unaffected offers.
  Overlap detection checks both active runs when one device has started another
  Voyage. Historical snapshot merging retains the larger earned total per resource
  for shared encounters. Resolved action replay adds only each accepted node's
  recorded earned deltas to the final completion bonus; rejected alternatives
  cannot reappear through a later cumulative tally.

#### Journal and economic replay

Offline journals retain each durable mutation's identity, ordering, and committed
effects using a checkpoint and lossless snapshot-field deltas. A receipt removes only the actions it actually submitted;
pending-request retries and reloads retain those same identities. Do not collapse
separate payouts into one snapshot pair: duplicate-claim detection would then
suppress unrelated earnings in the collapsed batch.
Journal equality includes the checkpoint even when history storage is shared,
so a prepared transition cannot accept a different replay baseline.

Battle rewards (including defeat XP), Salvage, Shop purchases, Homestead,
Mystery choices, forging, transmutation and inscription resolve complete actions
inside Persistence. `ResolvedSaveAction` records the before/after values, semantic
kind, and optional claim. Amounts, fractional effects, and XP are derived from
these stored values before catalog repair; replay never rerolls rewards or rereads
current prices. Each action includes its coupled item, equipment, encounter, and
progress changes. Composite transactions retain ordered child actions, including
intermediate purchase-and-salvage state that a final snapshot cannot reconstruct.
Sanitation and Library reconciliation become part of the finalized last action.
Commit retains full economic-coverage validation before publication or journaling.
XP deltas use Core's progression distance, independent of saturated lifetime totals;
coverage compares complete progressions. Current and historical economic replay
share effect arithmetic while retaining their separate claim-admission policies.

Action records use checkpoint-relative gap/change deltas; the last action reuses
the enclosing final snapshot instead of duplicating Inventory/map payloads. Each
child retains its production-consumption cursor. Preserve frozen pending prefixes,
request IDs, outbox row identities, and compensation. The [compatibility table](#save-compatibility)
owns format versions; economic edits in unowned gaps reject an upload.

Replay ownership is explicit:

| Fields | Owner for new action records |
|---|---|
| Coupled items, equipment, claims, routes, unlocks, and other structural effects | One action-level duplicate decision precedes changed-field structural reconciliation. A skipped action cannot grant an alternative item through snapshot union. |
| Gold, materials, XP and fractional balances | The same accepted action's derived receipt; structural merge does not decide these effects independently. |
| Homestead production credit | Existing consumed-coordinate union and production-cursor policy; partially overlapping collections pay only uncovered quantities. |
| Unrelated non-economic edits between or after actions | Changed-field residual reconciliation; economic edits in these gaps are refused. |
| Retired item identities | Replay state shared by the remote head; preserve retirement after Inventory removal. |
| Historical snapshot/economy/receipt records | Their existing version-specific reconciliation, without inventing missing action boundaries. |

Mystery records its choice and encounter completion as one action under the same
claim. Shop actions retain the pinned item and price. Distinct claims in one
transaction stay separate. Duplicate salvage and salvage after a shared purchase
retain retirement identity even after the original Inventory row disappears.

#### Homestead production identity

Homestead collections record pending credit, its production context, and per-resource
consumption coordinates within the reset epoch. The remote head unions consumed
ranges, including gaps from out-of-order uploads; overlapping collections pay only
the uncovered quantities. Local metadata caches the next coordinates so a gameplay
write never scans accumulated history. Action snapshots record the coordinates
already consumed locally, preventing stale pending credit from returning through
an unrelated reward. Spending does not alter these collection identities.
If concurrent earnings fill a balance, replay consumes only the production credit
actually paid and retains the unpaid portion for a later collection. Replaying the
same collection cannot restore that credit again.

#### Historical formats and outbox storage

Older records retain their version-one economic or conservative snapshot replay,
including historically compacted records whose separate actions cannot be recovered.
Current production commands always validate economic coverage, including an empty
receipt set for non-economic edits. Independent receipt authoring and unrestricted
snapshot-inferred writes are Debug-only fixture APIs for legacy replay coverage.
Preserve historical readers under the [compatibility table](#save-compatibility);
never reconstruct receipts whose separate actions are no longer recoverable.

`CloudOutboxRecord` stores checkpoint/action payloads as independent SwiftData rows.
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

#### Homestead cursor and legacy reconciliation

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

Reset advances the server epoch and invalidates older production claims. A later
offline upload merges its snapshot with the new epoch, so old progress can return;
both snapshots are backed up, and unrelated balances retain the larger value.
Concurrent stale reset requests cannot wipe a newer epoch. Signing out keeps a local copy and an
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
Unknown destination chapters fail admission and preserve the original payload;
they never substitute another chapter's boss or regenerate the saved board.

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
When both histories are opaque, retain the preferred branch's original bytes.
[Library](../Product/Library.md) owns player-facing unlock and discovery rules.
