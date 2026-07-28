# App Architecture Boundaries Plan

**Status:** Active
**Scope:** App-layer boundaries, `AppState` ownership, battle presentation ownership, and player-save write locality
**Execution rule:** This is a staged refactor. Each phase must ship green and remove the path it replaces before the next phase begins.

## Objective

Make the documented architecture enforceable without changing player-visible behavior:

1. Replace same-target folder conventions with compile-time module boundaries at stable seams.
2. Reduce `AppState` to composition, shell lifecycle, and top-level routing.
3. Reduce `BattleSession` to the active-battle lifecycle facade.
4. Make ordinary persistence mutations update only the affected save slices and child rows.

The end state keeps the existing package direction:

```text
TrinketCore
  ├── TrinketContent
  │     ├── BattleEngine
  │     └── TrinketPersistence
  └── TrinketDesignSystem

TrinketFeatureSupport
  ↑
TrinketBattleFeature
  ↑
TrinketAppState
  ↑
Trinket app
```

`TrinketFeatureSupport` may depend on `TrinketCore`, `TrinketContent`,
`TrinketPersistence`, and `TrinketDesignSystem`.
`TrinketBattleFeature` may additionally depend on `BattleEngine`.
`TrinketAppState` may depend on the packages above and owns composition of the battle
feature. None of these packages may import the `Trinket` app target.

## Current baseline

- `Trinket/` is one application target, so `App/`, `State/`, `Models/`,
  `BattleShell/`, `Shared/`, and all feature folders share one compiler namespace.
- `AppState` spans about 1,680 lines across seven files.
- `BattleSession` spans about 1,370 lines across six files.
- Twenty-four feature files request `AppState`; Play accounts for sixteen of them.
- A slice setter on `PlayerSaveStore` materializes and validates `PlayerSave`, then
  calls `PlayerSaveRoot.update(from:)`, which updates all six child slices.
- Roster, inventory, homestead, and Spires mappings replace child arrays rather than
  reconciling rows by stable identity.

Record these numbers again immediately before implementation. They are orientation
metrics, not targets to game through formatting or file splitting.

## Non-goals

- No player-facing UI, balance, reward, progression, animation, or audio changes.
- No rewrite of the intentional UIKit combat-feedback island.
- No split of `TrinketContent`.
- No protocol or wrapper for a single call site unless a new module boundary requires it.
- No package per screen or per tab. Only Battle, shared presentation support, and app
  state have enough current ownership pressure to justify new modules.
- No replacement persistence stack, schema redesign, or CloudKit enablement.
- No compatibility facades after call sites have migrated.

## Required order

Execute the phases in this order:

1. Establish behavioral and persistence baselines.
2. Make persistence writes slice-local.
3. Narrow feature access to `AppState` and introduce the Play owner.
4. Split battle presentation ownership.
5. Extract compile-enforced modules.
6. Remove obsolete paths and update durable architecture documentation.

Persistence comes first because later state moves must not preserve whole-graph writes
behind a new API. Ownership comes before module extraction so the new packages expose
small intentional APIs rather than publishing the current service-locator surface.

## Phase 0 — Lock behavior and evidence

### Work

- Inventory every `performBatchMutation` call and record the slices it is allowed to
  change.
- Inventory every `@Environment(AppState.self)` and categorize it as:
  shell routing, Play flow, Battle flow, Collection, Homestead, or Options.
- Inventory Battle consumers of feedback, outcome, cinematic, overlay, and simulation
  state.
- Capture the current path-scoped verification result for:
  `PlayerSaveStore`, `AppState`, `BattleSession`, and `BattleView`.
- Add tests only where the later refactor needs a consequential invariant that is not
  already covered. Do not add source-shape or line-count tests.

### Required invariants

- Existing save mutations survive store reload.
- A forced deferred-save failure restores the last durable state.
- Battle card play, end turn, victory, defeat, retreat, cinematic skip, and background
  suspension keep their current causal order.
- Existing battle performance scenarios remain measurable with the current harness.

### Exit gate

The inventory names every mutation and Battle lane owner. Existing verification is
green, or any pre-existing failure is documented before production edits begin.

## Phase 1 — Make persistence writes local

### Target design

Keep `PlayerSave` as the calculation, migration, reset, validation, and rollback
snapshot. Stop using a full graph update for ordinary successful writes.

Introduce an internal changed-slice representation covering:

- journey
- roster
- inventory
- homestead
- spires
- labyrinth
- root scalar metadata

`performBatchMutation` continues to offer atomic cross-slice behavior, but after
sanitization it compares the candidate with the prior snapshot and applies only the
changed slices. Property setters provide the known slice directly and use the same
write path.

### Work

1. Add slice-specific update methods on the existing SwiftData model owners.
   `PlayerSaveRoot.update(from:)` remains only for initial graph construction, reset,
   migration/sanitization repair, and explicitly full restores.
2. Convert scalar/blob-like slices first:
   journey, labyrinth, Spires, and root metadata.
3. Convert homestead child collections to reconcile by their domain IDs.
4. Convert inventory rows and affix rows to reconcile by stable IDs while preserving
   ordering through `sortIndex`.
5. Convert roster combatants, progression, ability loadouts, equipment loadouts,
   equipment slots, and stat rows to reconcile by their existing domain keys.
6. Make rollback restore only the slices touched by the failed transaction.
7. Preserve deferred-save coalescing and its single last-durable rollback snapshot.
8. Keep reset/seed/unlock-all on the explicit full-graph path.

Prefer explicit per-owner reconciliation over a generic graph framework. A small
collection reconciliation helper is acceptable only if at least three current model
owners use identical identity-preserving behavior.

### Tests

Extend the closest persistence tests to prove:

- Each single-slice setter survives reload without changing other slices.
- A multi-slice action updates all and only its declared slices atomically.
- Unchanged child models retain persistent identity across an unrelated write.
- Updating one inventory item does not recreate unrelated inventory or roster rows.
- Removing a child deletes only the missing row and preserves remaining ordering.
- Immediate and deferred save failures restore all touched slices.
- Full reset still replaces the complete save correctly.

Do not assert SwiftData implementation details that are not observable as identity,
row count, or reloaded behavior.

### Exit gate

- No ordinary successful property setter invokes the full `PlayerSaveRoot.update(from:)`.
- A batch mutation applies only the slices that differ after sanitization.
- Persistence package tests and path-scoped verification pass.

## Phase 2 — Narrow state ownership

### Target design

`AppState` owns:

- dependency construction
- app and scene lifecycle
- root tab/deep-link routing
- persistence recovery presentation
- composition of `PlaySession`, `BattleSession`, options, and audio

It does not expose forwarding properties for every player-save slice and is not
injected into feature subtrees.

Create `PlaySession` as the established owner for the Play tab because the current
Play flow already has sixteen `AppState` consumers and four substantial orchestration
extensions. Move the behavior, do not wrap or forward it.

`PlaySession` owns:

- campaign, Spires, and Labyrinth encounter orchestration
- active shop, mystery, and Labyrinth-node sessions
- preparation and activation of battles from Play
- Play return destinations and map focus
- coordination of persistence actions, without reimplementing their write rules

`BattleSession` remains a separate composed dependency. `PlaySession` may request
battle preparation/activation through its concrete session reference; Battle must not
reach back into `PlaySession`.

### Migration order

1. **Battle**
   - `BattleView` receives `BattleSession`, immutable completion inputs, and explicit
     actions for persist victory, retry, retreat, and SFX/options behavior.
   - Descendants may use `@Environment(BattleSession.self)` only within the Battle
     subtree.
   - Remove every Battle feature reference to `AppState`.
2. **Options**
   - Pass `OptionsStore` and an audio-preview action.
3. **Collection and shared detail views**
   - Pass roster/inventory snapshots and explicit equip, salvage, and selection
     actions.
   - Shared views must not accept `AppState`.
4. **Homestead**
   - Pass homestead/roster state plus existing `PlayerHomesteadStore` actions.
5. **Play**
   - Move `AppState+PlayJourney`, `AppState+Labyrinth`, `AppState+Spires`, and
     `AppState+Encounters` behavior into `PlaySession` extensions.
   - Move active encounter sessions, Play destinations, and map focus with that
     behavior.
   - Replace Play subtree `AppState` access with the narrowest owner:
     `PlaySession`, `BattleSession`, or an active encounter session.
6. Remove `AppState` save-slice forwarding properties and deleted extension files.

Feature roots should pass values and actions through initializers when the dependency
is shallow. Use an environment session only when multiple descendants genuinely
observe the same stateful flow. Do not replace `AppState` with broad `*Context`,
`*Dependencies`, or `*Manager` bags.

### Tests

- Move existing app orchestration tests to the new semantic owner.
- Keep app tests only for shell lifecycle and cross-feature routing.
- Add no tests for initializer plumbing or forwarding.
- Existing Play, encounter, Battle, Collection, Homestead, and Options journeys must
  retain their current owner and tier.

### Exit gate

- No file under `Trinket/Features/` or `Trinket/Shared/` references `AppState`.
- `AppState` contains no direct campaign, Spires, Labyrinth, shop, mystery, inventory,
  or homestead write rules.
- `AppState` exposes no `journey`, `roster`, `inventory`, `homestead`, `spires`, or
  `labyrinth` forwarding property.
- There is one Play orchestration path; the old `AppState+Feature` paths are deleted.

## Phase 3 — Split battle presentation ownership

### Target design

Keep `BattleSession` as the `@MainActor` facade for:

- active battle lifecycle
- authoritative `BattleState`
- `BattleSimBridge` mutation
- prepared-run activation
- play-card/end-turn commands
- scene suspension and auto-end eligibility

Keep `BattlePresentationState` as the observable combat projection.

Add one concrete `BattleFeedbackLane` for the existing performance boundary. It owns:

- feedback items and source-event bookkeeping
- per-target scheduling and prune timer
- hit, attack, and burst presentation state
- epoch publication required by the raster/UI lanes
- feedback bridge installation and updates
- feedback reset and memory trimming

Add one concrete `BattleSpectacleState` for:

- skill callout and cinematic state
- presentation holds and deferred feedback
- victory/defeat presentation state and summary
- pending outcome/celebration tasks
- spectacle reset and release

Pure interpretation stays in the existing presenters, recipes, policies, and mappers.
Do not move engine rules into these types.

Replace the direct `OptionsStore` and `SFXPlayer` properties on `BattleSession` with a
small, `@MainActor`, closure-backed `BattlePresentationEnvironment` defined at the
Battle boundary. It supplies only the current effects volume/SFX playback and Ultimate
skip decision needed by Battle. This seam is justified by the forthcoming module
boundary; it must not grow into an app dependency container.

### Work

1. Move feedback storage and methods as one behavior-preserving slice.
2. Point the UIKit raster bridge directly at `BattleFeedbackLane`.
3. Move spectacle/outcome observable state and task ownership.
4. Update Battle views to observe `presentation`, `feedback`, or `spectacle`
   directly; they must not observe the full session for display-only state.
5. Leave `BattleSession` commands as the only mutation entry from the UI.
6. Delete moved fields, forwarding methods, duplicate task cancellation, and the
   superseded `BattleSession+FeedbackPresentation` /
   `BattleSession+Presentation` paths.

### Tests and performance checks

- Move existing tests with their semantic owners; do not duplicate them.
- Preserve deterministic clock/delay seams.
- Verify bridge install/uninstall, prune/reset, background suspension, delayed
  auto-end cancellation, cinematic deferral, victory/defeat timing, and memory trim.
- Run the routed Battle performance verification. Do not claim a performance
  improvement without the repository performance evidence; the required outcome is
  no regression.

### Exit gate

- `BattleSession` owns no feedback collections, manual feedback bridge list, cinematic
  state, or victory/defeat presentation flags.
- Battle display views observe a narrow lane rather than `AppState`.
- Card play and end turn still publish one combat presentation snapshot per committed
  engine transition.
- Battle tests, routed UI canaries, and performance checks pass.

## Phase 4 — Enforce modules at compile time

Do this only after Phases 1–3 are green and files selected for extraction have no
`AppState` dependency in the wrong direction.

### 4A. `TrinketFeatureSupport`

Create `Packages/TrinketFeatureSupport` and move, rather than duplicate:

- `Trinket/Shared/`
- `Trinket/Features/Shared/`
- `Trinket/Models/`
- `PreparedArtworkCache` if its remaining consumers confirm it is shared by at least
  Battle and one non-Battle feature

Before moving, replace any remaining app-state reference with explicit values/actions.
Keep app-specific shell routing types out of this package.

Update UI tests to import the package product for `AccessibilityID` and frame-pacing
contracts instead of compiling the same authored files into two targets.

### 4B. `TrinketBattleFeature`

Create `Packages/TrinketBattleFeature` and move:

- `Trinket/Features/Battle/`
- battle session, projection, feedback, spectacle, and presentation recipe files from
  `Trinket/State/`
- `Trinket/BattleShell/`

Expose only:

- the Battle entry view/configuration
- `BattleSession` commands and narrow read lanes needed by the app
- `BattlePresentationEnvironment`
- explicit Battle completion/retreat actions required by the entry view

Do not make internal feedback, raster, recipe, or engine-mutation types public merely
to satisfy tests. Move their tests into the package that owns them.

### 4C. `TrinketAppState`

Create `Packages/TrinketAppState` and move:

- `AppState` and its remaining shell/bootstrap extensions
- `PlaySession` and encounter sessions
- `OptionsStore`
- app audio routing/playback
- `AppEnvironment` and shell/deep-link routing value types required by state

`TrinketAppState` may compose `TrinketBattleFeature`; the reverse dependency is
forbidden.

The application target retains:

- `TrinketApp`
- `ContentView` and root presentation
- Play, Collection, Homestead, and Options feature views
- bundle resources and platform entry configuration

### Project and gate updates

- Edit authored `Package.swift` files and `project.yml`; never hand-edit the generated
  Xcode project.
- Run the routed generation workflow and review generated changes.
- Update `check-module-boundaries.sh` to validate the actual package DAG and forbidden
  imports.
- Delete folder-string checks whose ownership is now guaranteed by the compiler.
- Update change classification, agent-context routing, and test routing for the new
  paths.
- Do not leave source files compiled in both their old and new targets.

### Exit gate

- State and Battle packages cannot import the app target or non-Battle feature views.
- `TrinketBattleFeature` cannot import `TrinketAppState`.
- The app target no longer compiles `State/`, `BattleShell/`, `Models/`, or shared
  support source directly.
- The boundary gate validates declared package edges rather than inferring Swift type
  ownership from folder-name searches.
- Generation is idempotent and all package/app tests pass.

## Phase 5 — Remove migration surface and update durable rules

- Delete this active plan when implementation is complete.
- Fold the final module graph, ownership table, and extension policy into
  `Docs/Platform/Architecture.md`.
- Update affected package READMEs, `AGENTS.md` files, AgentContext cards, and
  `Docs/Platform/Testing.md`.
- Delete forwarding wrappers, deprecated names, duplicate fixtures, and temporary
  access-control exceptions.
- Confirm `rg` finds no stale old paths or `AppState` feature injection.

## Verification matrix

Every phase uses the canonical changed-path gate once from the integrating agent:

```sh
./Scripts/verify-changed.sh --isolate --paths <all changed paths for the phase>
```

Additional minimum evidence:

| Phase | Minimum focused evidence |
|---|---|
| 0 | Existing routed unit/UI baseline |
| 1 | `TrinketPersistence` tests, reload/rollback/identity checks |
| 2 | App orchestration unit tests plus routed feature UI canaries |
| 3 | Battle unit tests, Battle UI canary, routed performance check |
| 4 | Package tests, generation idempotence, module-boundary gate, app unit/UI routes |
| 5 | Documentation/link checks through the changed-path gate |

Run `./Scripts/change-budget.sh` when surfaced by verification. Architectural necessity
does not justify compressed code or parallel compatibility paths; each phase must show
that production surface moved or shrank rather than only growing.

## Stop conditions

Stop and return a proposal rather than forcing implementation when:

- Current uncommitted work overlaps a phase and its intent cannot be established.
- A persistence change requires a schema migration rather than identity-preserving
  reconciliation.
- A Battle move changes event order, animation timing, or measured hitch behavior.
- A proposed package creates a dependency cycle.
- Module extraction requires publishing engine mutation APIs or app-wide dependency
  bags.
- Path-scoped verification exposes a pre-existing failure that cannot be separated
  from the refactor.

Do not continue to a later phase with a known failure or a compatibility wrapper
standing in for the old owner.

## Completion criteria

The plan is complete only when all four original issues are resolved:

1. **Compile-time boundaries:** the State, shared presentation, and Battle seams are
   separate modules with an acyclic enforced dependency graph.
2. **AppState ownership:** no feature/shared view receives `AppState`; Play behavior
   lives on `PlaySession`; save-slice forwarding and feature write rules are removed.
3. **Battle ownership:** `BattleSession` is the lifecycle/simulation facade, while
   feedback and spectacle state have independent owners and observation lanes.
4. **Persistence locality:** normal writes touch only changed slices and reconcile
   children by stable identity; atomicity, reload, and rollback behavior remain green.
