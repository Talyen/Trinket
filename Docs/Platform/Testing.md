# Testing

Package, script, and UI test conventions for Trinket. Command routing: [Verification.md](Verification.md).
Battle ownership matrix: `Packages/BattleEngine/Tests/README.md`. UI launch args / speed:
`TrinketUITests/README.md`. Coverage decision below is canonical; `AGENTS.md` points here.

## Framework split

**Swift Testing only** in package test targets (`import Testing`). **XCTest** only in `TrinketUITests/`. Enforced by `./Scripts/check-api-bans.sh`.

Keep semantic tests beside their owning package; there is no app-level `TrinketTests`
target (final app-target integration behavior that packages cannot own lives in
`TrinketAppStateTests` or a UI smoke owner). SwiftUI shipping
journeys use UI smoke/deploy only when the keep/drop rubric below applies.

## Ownership

| Concern | Owner |
|---------|-------|
| Battle rules / handlers / golden paths | `Packages/BattleEngine/Tests/` (see that package’s README) |
| Shared presentation models / caches / frame analysis | `Packages/TrinketFeatureSupport/Tests/` |
| Design tokens / motion / reusable chrome | `Packages/TrinketDesignSystem/Tests/` |
| Battle session / feedback / spectacle | `Packages/TrinketBattleFeature/Tests/` |
| AppState / Play and encounter sessions / options / audio routing | `Packages/TrinketAppState/Tests/` |
| Catalogs / content invariants | `TrinketContentTests` |
| Stores / persistence write-through | `TrinketPersistenceTests` |

## Fixtures

Prefer `TrinketContentTestSupport` for shared combat, content, and
battle-party fixtures (`CombatantFixtures`, `ItemFixtures`,
`BattlePartyFixtures`). Save harnesses belong to `TrinketPersistence`'s
`TrinketPersistenceTestSupport` target so shared combat fixtures stay Persistence-free.
The fixture implementations live in `TrinketContent`'s `TrinketContentTestSupport`
target so `TrinketContentTests` can use them without a package cycle.
Protect fixture behavior through the game outcomes exercised by consuming tests;
avoid separate snapshots of fixture defaults, names, or forwarded predicates.
Package-specific construction, RNG, and
dispatch conventions belong in the owning test guide, including
[BattleEngine](../../Packages/BattleEngine/Tests/README.md#conventions) and
[Persistence](../../Packages/TrinketPersistence/Tests/README.md).

When an API signature or combat rule changes, review consumers across production
code, package tests and shared fixtures using the existing
[caller investigation](../AgentContext/Retrieval.md#caller-navigation). Include
unchanged consumers and migrate them in the same change. Repeat that review after
incorporating current main before integration; a lightweight handoff does not prove
Swift compilation. Retire an old expectation only after identifying the surviving
behavioral contract.

For balance changes, use authored catalog values to construct fixtures while keeping
explicit expected gameplay outcomes that can catch an incorrect authored value.
Assert numeric rules through typed results; localized-string assertions belong to
presentation contracts and must use the intended locale/formatting behavior.

Seed streams are separate universes, not one constant: the battle RNG seed
(`CombatantFixtures.deterministicBattleSeed`, with
`deterministicBattleSeedVariant(_:)` for independent streams) is the shared
combat seed. The save world seed (`PlayerSave.testWorldSeed`), the perf
fixture seed (`BattlePerformanceFixture.seed`), and the generated-item seed
(`SaveTestSupport.makeGeneratedItem`, default `11`) are intentionally
distinct; do not unify them or reuse the battle seed for non-battle RNG.

Known intentional forks (do not "fix" toward a single default):

- Enemy HP: `1` in `quickWinParty` (fast victories) vs `100` in
  `BattleSessionTestSupport.makeConfiguredSession` (durable sessions) vs
  `100/1000` hero/enemy in `makePassiveSession` (durability probes). Consuming
  session outcomes protect these fixtures; do not add separate default snapshots.
- Item IDs: `"<base>-test"` from `ItemFixtures.makeBareItem` (avoids catalog
  collision) vs `"<baseID>-<rarity>"` from `SaveTestSupport.makeGeneratedItem`
  (generator shapes). `SaveTestSupport.makeSave` defaults inventory to empty
  while launch helpers seed both roster and inventory.
- `BattleRunConfigurationTestSupport.make` (feature-level configuration) and
  `BattleSessionTestSupport.makeConfiguredSession` (live session) overlap in
  defaults but exercise different paths; both live in
  `TrinketBattleFeatureTests/Support/` (test-target-internal, not a shared
  support target).

## Unit conventions

- **Naming:** `@Test func behaviorWhenCondition()` — no `test` prefix required.
- **Assertions:** `#expect`; `try #require` / `#require` to unwrap; `Issue.record` for unconditional failures.
  - Keep `#require` arguments simple `Optional`s (or values that expand cleanly). Compute rich expressions first — e.g. `let node = collection.first(where: \.flag); try #require(node)` — so Swift Testing macros do not emit “missing try” compile errors.
  - Prefer key-path `first(where:)` / `contains(where:)` forms when SwiftLint `prefer_key_path` applies; still split before `#require`.
- **Parameterization:** `@Test(arguments:)` for catalog loops and symmetric keyword variants.
  - If the argument type is a `private` nested enum/struct, the `@Test` function must also be
    `private` (Swift rejects a more-visible method that exposes a private parameter type).
  - Argument types used in `@Test(arguments:)` tuples must be `Sendable` (and usually
    `Hashable` / `Equatable`). Nested types like `Keyword.Category` need the same
    conformances even when the parent type already has them.
- **Lifecycle:** Prefer `@Suite` on package tests. Use `@MainActor` when UI/layout/store isolation requires it. Use `final class` + `init() throws` only for teardown ownership (`AppTestContext` / `PersistenceTestContext`).
- **Stores (persistence reload semantics):** mutate → close/reload from disk → `#expect`; an in-memory accessor/setter round trip is not persistence coverage.
- **Async/debounce:** await an owned scheduled task when its completion is the contract; otherwise use bounded polling. Inject short intervals when testing a delay; never `Task.sleep` for multi-second production delays. Main-actor contention must not turn successful scheduled work into a failed wall-clock poll.
- **Events:** pin outcome counters; assert event *semantics*, not full log fingerprints.
- **Script runners:** exercise real selection and execution with minimal sentinel
  suites; avoid recursively running unrelated regression suites just to prove runner
  plumbing. Keep backend failure propagation and missing-execution protection covered.
- **Tier fit:** Keep package tests deterministic and credential-free; real CloudKit I/O and physical audio playback need integration/device evidence. Presentation logic can merit unit coverage for consequential contracts such as finite geometry, interruption continuity, and resource cleanup; apply the coverage decision below.

## Coverage decision (new and changed behavior)

Default to no new test. Before adding or expanding one, answer three questions:

1. **What consequential failure does it catch?** Name a credible harmful outcome
   or safeguard failure. For a repair, the assertion should fail before the fix.
2. **Is that gap already covered?** Read existing assertions; test names and
   routing pointers alone do not establish protection.
3. **Is this the cheapest reliable protection?** Use the smallest suitable owner
   and account for runtime, setup, brittleness and maintenance.

Add coverage when those answers establish substantial protection beyond existing
assertions (high marginal value). Save loss, duplicated rewards, wrong battle
resolution, blocked progression and purchase-access failures are strong candidates.
A new API, a reported bug, a distinct branch or cheap execution alone is insufficient.
Briefly explain the harmful outcome and coverage gap when adding a test; no value
labels, manifests or separate approval are required. Rare medium-value additions
need a concrete readability or diagnostic benefit. Skip low-value tests that mirror
implementation, trivial plumbing, incidental copy/style or framework behavior.

Prefer shared invariants, representative behavior families and meaningful boundaries.
Use the owning package for rules/models, Persistence for durable save semantics,
and AppState for application transitions packages cannot own. Existing catalog
matrices can protect many content entries; do not create a UI journey per mechanic.
A new player flow needs a stable `AccessibilityID`, but needs new UI coverage only
under the keep/drop rubric below. Assert meaningful outcomes with stable selectors.

### Consolidation and retirement

Keep the smallest effective portfolio in the area being changed. Consolidate or
retire redundant and low-value cases when their confidence does not justify their
cost; no separate approval or replacement test is required. Explain what retired
coverage protected and identify the surviving owner, or the deliberately relinquished
protection and material risk. Preserve effective save, battle and progression evidence.
Never remove or weaken an assertion to hide a failure or avoid diagnosing slowness.

Judge cost by executions, setup, launches, waits and diagnostic clarity. Parameterizing
cases may remove source duplication without reducing executed work. Keep unrelated
journeys separate and remove fixtures or registrations left unused by retirement.

### Presentation / accessibility-ID changes (before push)

Renaming or rewiring `AccessibilityID`, a view `accessibilityIdentifier`, or a
Homestead/Play interaction contract follows
[UI verification requirements](Verification.md#choosing-ui-verification).
Stable identifiers must be applied at the modifier that remains visible to
XCUITest (for example, the shared glass CTA modifier).

## UI keep / drop rubric

UI tests selectively prove critical journeys and interaction wiring once; battle
rules belong in package tests, and cross-module contracts use the cheapest tier that
actually exercises the boundary. “Exhaustive” is a suite name, not a coverage obligation. The bounded [real-player portfolio](PlayerCoverage.md) adds interruption, restored-control, settings-profile, and recovery protection.

Apply the coverage decision to additions and the retirement rules to existing cases.
UI tests must provide high-value protection for a **shipping product outcome** that
package tests cannot prove, with only the rare medium-value exceptions described
above. Account for app launches, waits, flakiness, and harness maintenance. These
categories are eligible outcomes, not sufficient reasons to add a journey:

1. **Shell / entry** — a major surface becomes usable (Play chooser, Homestead wallet, Shop controls, Battle chrome).
2. **State-changing journey** — a user action mutates durable or navigable state (shop leave returns to Play, retreat returns to Play, recruit continue).
3. **Safety invariant** — a wrong interaction must not happen (locked slot inert; hand drag must not open detail). **One owner only** across smoke + exhaustive.

Avoid UI tests that mirror incidental copy or chrome, race live ticks during long
detail journeys, or duplicate the same failure mode across smoke and FullUI. A
focused layout or scroll/gesture regression is appropriate when it protects a
consequential outcome, such as reaching a control, that a cheaper tier cannot prove.
Push loadout, party-selection, and unlock rules down to package tests when possible.
Prefer one focused journey proving a critical outcome over repeated control or
detail checks. Existing release-critical journeys retain their requirements; a
smaller declaration count does not justify a long combined journey.

**Brittleness:** locate product controls by `AccessibilityID` and assert the meaningful
outcome. Native system chrome and controls that omit their assigned identifiers use the
[system-query allowlist](../../Scripts/config/uitest-system-query-allowlist.txt),
including SwiftUI's Back and Close controls and native submenu entries. Keep each
exception tied to its native-query limitation; ordinary product queries retain
their stable identifiers. Avoid incidental display names, rarity labels, or exact scroll geometry;
assert those values only when they are themselves the contract being protected.

Smoke/full-UI class membership and launch details belong to
[`TrinketUITests/README.md`](../../TrinketUITests/README.md); this document owns
only the semantic keep/drop rubric above. Command selection and isolation belong
to [Verification.md](Verification.md).

## UI execution notes

Frame pacing and app-journey metrics are outside smoke and routine push CI.
Manual hosted performance diagnostics and expressly requested local measurements
follow the [performance playbook](PerformanceInvestigationPlaybook.md).
Launch-arg catalog, speed rules, and mid-battle guidance live in
[`TrinketUITests/README.md`](../../TrinketUITests/README.md); command selection and
isolation belong to [Verification.md](Verification.md).
