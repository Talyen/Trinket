---
type: execution-plan
status: active
created: 2026-08-20
updated: 2026-08-20
expires: 2026-09-03
---

# Post-Battle Talent Choice

## Objective

After a victory grants one or more new Talent Points, offer a lightweight, dismissible reminder that lets the player allocate one Talent Point for each active combatant whose earned point total increased in that battle.

The flow first asks the player to choose one of that combatant's three Talent Trees, then shows only the nodes currently legal in that tree. It reuses the visual language of Combatant Detail and the existing Talent Nodes screen without changing talent balance, row-gating rules, or the normal talent-editing path in Collection.

## Confirmed product behavior

- Trigger only after a successful battle completion has persisted its XP and rewards.
- Include a combatant only when that battle increased their `totalTalentPoints`. Pre-existing unspent points alone do not trigger the flow.
- Queue the Hero first and Companion second when both gained at least one point.
- Offer at most one allocation per queued combatant, even if the battle crossed multiple even levels or the combatant already had other unspent points.
- The player may dismiss the entire flow without allocating anything. Dismissal is transient, requires no confirmation, and is not restored after relaunch.
- A dismissed combatant is not reminded after ordinary later victories. They enter this flow again only after a later battle grants them another Talent Point.
- Spending a point is immediate and permanent under the current product rules. Do not add respec, reset, undo, or an additional confirmation alert.
- Preserve the existing Collection > Combatant Detail talent editor as the place to allocate any remaining points later.

## UX flow

### Entry and dismissal

1. The player completes the existing Victory reward reveal and taps Continue.
2. Play persists the battle outcome. If persistence fails, keep the existing Victory retry behavior and do not present the talent flow.
3. Play installs the transient reminder state, then closes the battle. The normal return destination is restored behind a full-screen cover without exposing an intermediate interactive frame.
4. If either active combatant crossed a Talent Point boundary, present the talent flow. Otherwise, return normally.
5. Allow native interactive dismissal and show a visible trailing Close control at every navigation depth. Closing or swiping down abandons the complete remaining queue; talents already chosen remain saved. Funnel both paths through the same `PlaySession` dismissal action so an interactive dismissal cannot leave a hidden queue behind.

The cover is intentionally transient. Do not add a save-model field for a pending reminder or inspect all unspent points on app launch.

### Combatant tree selection

Use a dedicated tree-selection root rather than the full Combatant Detail screen:

- Reuse the cinematic combatant artwork/header treatment from Combatant Detail.
- Use `CHOOSE A TALENT` as the context and the combatant's name as the primary identity.
- Explain that the combatant earned a Talent Point and ask the player to choose a Talent Tree.
- Show the three established Talent Tree cards in their authored order, using each tree's existing artwork, name, and keyword styling.
- Show the number of currently legal choices in each tree. Keep a completed/unavailable tree visible but disabled so the three-tree structure remains understandable.
- Do not expose future-row nodes on this screen.
- Use a native trailing toolbar Close control. Do not add a bottom CTA until a node has been selected in the tree detail.

### Tree node selection

Pushing a tree uses standard `NavigationStack` navigation:

- Let the system provide the leading Back chevron to return to tree selection.
- Keep the trailing Close control available so dismissal never depends on discovering a gesture or navigating back to the root.
- Reuse the existing Talent Tree artwork/header, node-card treatment, selected-node shine, description inspector, and primary action styling.
- Filter the grid to nodes for which `TalentTree.canUnlock` is true against the latest saved roster. Do not show already unlocked nodes, locked future rows, or placeholder slots.
- Rely on the current row-gating invariant: an incomplete tree has one or two legal nodes, all in its earliest incomplete row. Render that single legal row rather than preserving empty space for the hidden 2x3 tree.
- Default selection to the first legal node so the artwork, name, description, and action are immediately coherent.
- Keep node selection non-destructive. Commit only when the player taps `Unlock Talent`.
- On a successful save, give the established selection feedback and advance to the next queued combatant's tree-selection root. If none remain, dismiss the cover and reveal the already-restored Play destination.
- If the selection becomes unavailable, refresh the legal choices without advancing. If persistence fails, remain on the same node screen and show a concise save-failure alert.

### Two-combatant sequence

- Queue order is Hero, then Companion.
- After the Hero chooses one talent, replace the cover's content with the Companion tree-selection root and reset the local navigation path.
- If the player dismisses before either choice or while choosing for the Companion, end the complete reminder flow.
- Do not show progress pagination, celebratory interstitials, or a summary screen. The combatant identity and automatic advance provide sufficient orientation for a maximum two-step flow.

## State and ownership design

### Detect the event after persistence

Keep reward mutation in Persistence and flow orchestration in `PlaySession`:

1. Immediately before completion, snapshot the progressions for the battle configuration's Hero and Companion IDs from `PlayerSaveStore.roster` as the before-values. Do not rely on the battle configuration's launch-baked progression or re-resolve whichever party is active later; the save is the mutation authority, while the configuration identifies who actually fought.
2. Run the existing mode-owned completion closure through `PlayBattleCompletion`.
3. Only after it returns success, read each combatant's persisted progression from `PlayerSaveStore.roster`.
4. A combatant qualifies when:
   - `after.totalTalentPoints > before.totalTalentPoints`, and
   - the persisted roster still reports at least one available Talent Point.
5. Build one transient queue entry per qualifying combatant, regardless of the size of the point increase.

Comparing earned totals rather than available-point counts is important: an old unspent point must not cause a reminder, while crossing more than one even level still creates only one queue entry.

Have `PlayBattleCompletion` invoke a narrow post-persist callback after the mode completion succeeds but before it queues the return destination and calls `battle.endBattle()`. `PlaySession` uses that callback to compare the snapshots and install the transient queue. This preserves the existing persist -> return-route -> end-battle authority while ensuring SwiftUI never observes an ended battle without the reminder state that should follow it. Keep the existing public `completeActiveBattle(...) -> Bool` contract intact.

### Transient flow model

Keep a private ordered `[String]` queue of qualifying combatant IDs on `PlaySession`, with a public read-only current combatant ID derived from its first element. That is sufficient to drive a stable `fullScreenCover(isPresented:)`; do not introduce a public flow DTO, UUID identity, role enum, or persistence schema. Resolve the combatant role, artwork, progression, trees, and unlocked-node state from `GameContent` and `PlayerSaveStore` so each screen uses current saved truth.

`PlaySession` should expose narrowly scoped actions:

- dismiss the current talent reminder;
- choose a node for the current combatant;
- advance after a successful persisted unlock.

The app view presents the flow; AppState decides when it exists and coordinates queue advancement. `TrinketFeatureSupport` owns reusable talent presentation. Persistence continues to own the legal roster mutation and disk write.

Clear this queue from `PlaySession.clearTransientState()` alongside battles and encounter sessions so reset, reseed, and session teardown cannot leave a reminder pointing at replaced save data. Normal dismissal and final allocation also empty it. The cover prevents another battle launch through normal UI; do not add speculative launch guards unless an existing programmatic path can be shown to bypass that presentation.

### Minimal package boundary

Draft the implementation around this small public surface before writing the views:

```swift
// TrinketPersistence
public enum TalentUnlockResult: Equatable, Sendable {
    case unlocked
    case unavailable
    case persistenceFailed
}

@MainActor
public extension PlayerSaveStore {
    func unlockTalent(
        nodeID: String,
        treeID: String,
        for combatantID: String
    ) -> TalentUnlockResult
}

// TrinketAppState / PlaySession
public var currentPostBattleTalentCombatantID: String? { get }
public func dismissPostBattleTalentChoice()
public func choosePostBattleTalent(nodeID: String, treeID: String) -> TalentUnlockResult
```

The queue remains private. `choosePostBattleTalent` must target the current queued combatant rather than accepting a caller-supplied combatant ID, then remove exactly that entry only on `.unlocked`. The app target already imports AppState, Persistence, Content, and FeatureAdapters, so this surface adds no reverse dependency and does not expose SwiftUI through AppState.

### Talent mutation

Wrap the existing `PlayerRosterState.unlockTalent` rule in a `PlayerSaveStore` roster-domain action that persists atomically and distinguishes an unavailable choice from a disk-write failure. Resolve the canonical combatant config, tree, and node from their IDs before mutation; do not trust caller-constructed `TalentTree` or `TalentNode` values. This closes the existing rule's assumption that the supplied node belongs to the supplied tree and combatant.

Revalidate the chosen tree/node against the latest unlocked set and available-point count at commit time. Use the immediate `persistBatch`/rollback path so `.unlocked` means durable success and `.persistenceFailed` leaves both the observed roster and save graph unchanged. Advance the transient queue only on `.unlocked`; refresh legal choices without a save alert for `.unavailable`, and show the save-failure alert only for `.persistenceFailed`.

Do not route the existing Combatant Detail editor through the new immediate-save action as part of this feature unless implementation reveals a correctness requirement. Its current deferred write behavior is outside this flow's scope; visual reuse alone is not a reason to change its mutation semantics.

## Presentation implementation

### Reuse and extraction

Extend the existing talent presentation instead of creating a second visual implementation:

- Extract the visual tree-card content so Combatant Detail and the reminder root share artwork, naming, and keyword state while retaining their different footer metrics (`unlocked/total` versus `legal choices`). Do not create a generic picker abstraction for only these two callers.
- Prefer extracting the reusable Talent Tree artwork/node/inspector content into thin full-tree and choice-screen wrappers. If a small input parameter is genuinely simpler, parameterize `CombatantTalentsView` with visible nodes and Reset availability, but avoid a growing presentation-mode enum with unrelated branches.
- Keep app routing and the post-battle queue out of `TrinketFeatureSupport`.
- Put the Play-specific cover/composition under `Trinket/Features/Play/` and present it from the existing Play presentation modifier.

Present the cover from a dedicated small modifier that observes only the talent-flow slice of `PlaySession`, mirroring the existing Battle/encounter presentation isolation. Do not make the browsing stack observe talent-node selection or unlocked-set changes. Keep the background destination restoration unchanged; it may update behind the cover after `activeBattle` becomes nil.

Do not define pixel-level layout, new artwork, or novel motion in this phase. Those decisions belong to the later visual mockup pass. Implementation should initially rely on current DesignSystem metrics and components.

Before UI implementation, complete the separately requested visual mockup pass and amend only the presentation details it settles. The state, persistence, trigger, and dismissal contracts in this plan should remain independent of those visual choices.

### Accessibility and native behavior

- Add stable accessibility identifiers for the flow root, Close control, each Talent Tree, legal Talent nodes, and the unlock action.
- Preserve native button labels and the system Back action.
- Announce the combatant name, that a Talent Point was earned, the tree name, and each node's current availability without relying on color or shine.
- Allow Dynamic Type content to scroll rather than fixing the header/body to a non-growing height.
- Use existing DesignSystem reduced-motion, contrast, transparency, and press-feedback behavior; do not add feature-local accessibility branches.
- Keep interactive dismissal enabled because leaving is explicitly non-destructive.
- When advancing Hero -> Companion, reset navigation and accessibility focus to the new combatant heading. When legal nodes change under an open tree, move selection to a remaining legal node instead of leaving focus or the inspector on an unavailable choice.

## Edge cases

- Defeat or retreat: never present.
- Victory persistence failure: never create the queue; retain the existing retry surface.
- Previously claimed Journey rewards/replay with no persisted XP: never present, even if launch-time presentation data predicted XP.
- Only one combatant crosses an even level: show one step.
- Both cross an even level: show Hero then Companion.
- One combatant crosses multiple even levels: show one step and spend at most one point.
- A qualifying combatant already has unspent points: still show one step because a new point was earned, but do not force spending the full balance.
- A non-qualifying combatant has unspent points: do not include them.
- Player dismisses at any depth: clear the entire transient queue and return to Play.
- Player chooses for Hero then dismisses during Companion: keep the Hero talent and abandon the remaining queue.
- Legal choices change or disappear before commit: revalidate, stay in place, and refresh or exit that combatant safely rather than unlocking an illegal node.
- The current combatant spends their last available point elsewhere while the cover is open: skip that now-inapplicable queue entry and advance or dismiss instead of showing an empty tree chooser.
- A catalog/config lookup unexpectedly fails: skip the invalid queue entry and log it; do not call the catalog's precondition-based accessor from unvalidated transient IDs.
- App termination during the flow: persisted choices survive; the reminder queue does not.
- A tree is fully completed while another has legal nodes: show the completed tree disabled on tree selection and omit all nodes from it.

## Expected code areas

- `Packages/TrinketAppState/Sources/TrinketAppState/State/PlaySession.swift`
  - transient reminder state, post-completion qualification, dismissal, and queue advancement.
- `Packages/TrinketAppState/Sources/TrinketAppState/State/PlaySession+BattleCompletion.swift`
  - preserve persist-before-dismiss semantics; adjust the completion result/callback only as needed to let `PlaySession` compare persisted progression.
- `Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore+Roster.swift`
  - canonical ID validation, explicit unlock result, and atomic persisted talent-unlock action.
- `Packages/TrinketFeatureSupport/Sources/TrinketFeatureAdapters/Shared/Detail/CombatantTalentsView.swift`
  - legal-node-only choice presentation while preserving the existing full-tree mode.
- `Packages/TrinketFeatureSupport/Sources/TrinketFeatureAdapters/Shared/Detail/CombatantDetailPane.swift`
  - share or extract the established three-tree selection cards if needed.
- `Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Shared/AccessibilityID.swift`
  - stable selectors for the new flow.
- `Trinket/Features/Play/PlayBrowsingStack.swift`
  - attach a narrowly observed talent-flow cover modifier to the existing Play presentation layer.
- A small Play-specific view under `Trinket/Features/Play/` for the cover and its navigation stack.

Exact touched paths should be reclassified with `agent-context.sh` once implementation settles whether the shared tree-card extraction is necessary.

The worktree already contains unrelated edits in several likely touched files, including PlaySession and talent presentation. Before implementation, inspect their current diffs and preserve them; do not implement from HEAD assumptions or include unrelated changes in verification/commit scope.

## Test plan

### AppState behavior

Add focused tests proving:

- no reminder when neither combatant's earned point total increases;
- Hero-only, Companion-only, and Hero-then-Companion qualification;
- pre-existing unspent points do not qualify a combatant without a new earned point;
- crossing multiple even levels produces one queue entry;
- failed battle completion/persistence produces no queue;
- a repeated/double completion cannot duplicate the queue;
- successful Hero allocation advances to Companion;
- dismissing clears the remaining transient queue without changing talents;
- successful final allocation clears the flow;
- failed/illegal allocation does not advance;
- reset/session teardown clears the transient queue;
- the queue is installed before battle end is observable.

### Persistence behavior

Extend talent persistence coverage to prove the store action:

- accepts a legal node, spends exactly one point, and survives store reload;
- rejects a locked, duplicate, wrong-combatant, or no-point node without partial mutation;
- reports a forced save failure without leaving the in-memory/save graph in an advanced state;
- distinguishes `.unavailable` from `.persistenceFailed` so UI error handling is accurate.

### Presentation behavior

Prefer state/model tests over layout assertions. Add coverage only for consequential filtering/sequence logic:

- tree choice counts include only currently legal nodes;
- the tree detail receives legal nodes only and selects a valid initial node;
- changing from Hero to Companion resets tree navigation;
- losing the selected node or the last available point while presented refreshes/advances without a dead-end.

Add one narrow UI smoke journey only if the existing launch fixtures can deterministically cross a Talent Point boundary without creating a second fixture system. It should cover Victory Continue -> reminder entry -> tree -> node -> persisted unlock. Unit coverage owns the two-combatant and dismissal matrix.

## Verification

During implementation, run the cheapest package tests after each ownership slice, then the canonical path-scoped gate:

1. `TRINKET_ISOLATE=1 ./Scripts/test-package.sh TrinketPersistence`
2. `TRINKET_ISOLATE=1 ./Scripts/test-package.sh TrinketAppState`
3. `TRINKET_ISOLATE=1 ./Scripts/test-package.sh TrinketFeatureSupport`
4. Any selected Play UI smoke target if the test rubric admits it.
5. `./Scripts/handoff.sh --isolate --paths <all touched authored files>`

Before implementation handoff, also inspect the real flow at normal and accessibility Dynamic Type sizes, verify native Back/Close/swipe dismissal, exercise reduced motion and increased contrast through shared components, and confirm that a save failure cannot dismiss or advance the flow.

## Non-goals

- Visual mockups or final pixel-level layout.
- Talent balance, point cadence, tree structure, or row-gating changes.
- Showing the reminder after every victory with unspent points.
- Spending more than one point per combatant per reminder.
- Mandatory allocation, confirmation dialogs, respec, reset, or undo.
- Persisting or restoring the reminder queue.
- Surfacing inactive roster combatants with unspent points.
- Replacing the existing Collection talent editor.

## Execution checklist

- [ ] Re-run path classification after final implementation paths are known.
- [ ] Specify the minimal AppState flow value and public boundary before coding.
- [ ] Add the atomic roster talent-unlock store action and persistence tests.
- [ ] Detect newly earned Talent Points only after successful battle persistence.
- [ ] Add transient Hero/Companion queue orchestration and AppState tests.
- [ ] Complete and approve the separate visual mockup pass; amend presentation-only details without changing flow contracts.
- [ ] Build the dismissible tree-selection root and legal-node drill-in using shared talent presentation.
- [ ] Add accessibility identifiers and focused presentation coverage.
- [ ] Run package tests and the path-scoped isolated handoff gate.
- [ ] Delete this active plan when implementation is complete; fold any durable product decision into its canonical documentation owner.
