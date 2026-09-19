# Testing

Unit and UI test conventions for Trinket. Command routing: [Verification.md](Verification.md).
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
Fixture contracts (seed, defaults, ID scheme, name derivation, quick-win shape)
are pinned by `FixtureContractTests` in `TrinketContentTests`. Package-specific construction, RNG, and
dispatch conventions belong in the owning test guide, including
[BattleEngine](../../Packages/BattleEngine/Tests/README.md#conventions) and
[Persistence](../../Packages/TrinketPersistence/Tests/README.md).

Seed streams are separate universes, not one constant: the battle RNG seed
(`CombatantFixtures.deterministicBattleSeed`, with
`deterministicBattleSeedVariant(_:)` for independent streams) is the only
pinned seed. The save world seed (`PlayerSave.testWorldSeed`), the perf
fixture seed (`BattlePerformanceFixture.seed`), and the generated-item seed
(`SaveTestSupport.makeGeneratedItem`, default `11`) are intentionally
distinct; do not unify them or reuse the battle seed for non-battle RNG.

Known intentional forks (do not "fix" toward a single default):

- Enemy HP: `1` in `quickWinParty` (fast victories) vs `100` in
  `BattleSessionTestSupport.makeConfiguredSession` (durable sessions) vs
  `100/1000` hero/enemy in `makePassiveSession` (durability probes, pinned in
  `BattleSessionSupportDefaultsTests`).
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
- **Async/debounce:** inject short intervals in production inits; poll in tests — never `Task.sleep` for multi-second production delays.
- **Events:** pin outcome counters; assert event *semantics*, not full log fingerprints.
- **Tier fit:** Keep package tests deterministic and credential-free; real CloudKit I/O and physical audio playback need integration/device evidence. Presentation logic can merit unit coverage for consequential contracts such as finite geometry, interruption continuity, and resource cleanup; apply the coverage decision below.

## Coverage decision (new and changed behavior)

Maintain the smallest test portfolio that provides strong confidence in consequential
game behavior. Verification does not imply authoring new tests; existing coverage
or no new test can be the right outcome. Add or expand coverage only when all are true:

1. The change introduces or repairs a distinct, consequential behavior or invariant.
2. Existing assertions do not already prove the changed behavior or invariant.
3. The proposed assertion would fail before the fix, except for genuinely new behavior.
4. The cheapest suitable tier can express it without duplicating a stronger owner.
5. Its added confidence justifies its runtime, setup, brittleness, and maintenance.

Prefer shared invariants, representative behavior families, and meaningful boundaries.
Hundreds of mechanics do not justify per-mechanic UI journeys or exhaustive combination
matrices. Add mechanic-specific cases or targeted interaction regressions when they
exercise materially different, consequential failure modes. Cheap catalog-wide
invariants remain useful when they detect content errors that representative cases
cannot; case count alone establishes neither value nor waste.

Prefer an existing semantic owner when the behavior fits coherently; a new file or
suite is appropriate when it improves cohesion and diagnostics. Remove or merge
coverage made redundant by the change. Avoid assertions that merely mirror plumbing,
stored properties, incidental copy, style constants, framework behavior, or trivial
delegation. Judge the contract and failure mode rather than banning an entire
implementation category.

**Likely owners when the gate passes:** rules/models → owning package; persistence semantics → existing store/sanitizer journey; catalog content → invariant matrix, not exact-count snapshots; novel `EffectKind` behavior → existing registry/handler matrix; consequential app transitions that packages cannot own → `TrinketAppStateTests`.

New user flows still need a stable `AccessibilityID` selector (or an existing appropriate one), but add or extend a UI test only when the keep/drop rubric below applies. Prefer a coherent existing smoke/exhaustive journey over a new class. Use stable identifiers to locate controls; assert meaningful outcomes without pinning incidental accessibility wording.

### Consolidation and retirement

Proactively consolidate, streamline, move, or delete tests in the area being changed
when the evidence justifies it; no separate approval or replacement test is required.
For redundant coverage, identify the surviving owner and the relevant conditions it
proves. A distinct case may also be retired when its practical confidence is too low
for its cost. Explain what it proved, why it is being retired, and the surviving
protection or deliberately relinquished coverage and material remaining risk.

Preserve effective protection for consequential contracts such as save integrity,
meaningful battle invariants, and critical player outcomes. Failure or slowness alone
is not grounds for removal; diagnose failures and never delete or weaken assertions
to conceal a defect. Distinctness alone is not a reason to keep a low-value case.

Judge simplification by maintenance, expanded executions, setup, launches, waits,
and diagnostic clarity. Parameterization can reduce duplication without reducing
executed work. Do not combine unrelated cases into a long journey merely to lower
declaration counts. Remove unused fixtures and support code left by retirement.

### Presentation / accessibility-ID changes (before push)

Renaming or rewiring `AccessibilityID`, a view `accessibilityIdentifier`, or a
Homestead/Play interaction contract follows
[UI verification requirements](Verification.md#choosing-ui-verification).
Stable identifiers must be applied at the modifier that remains visible to
XCUITest (for example, the shared glass CTA modifier).

## UI keep / drop rubric

UI tests selectively prove critical journeys and interaction wiring once; battle
rules belong in package tests, and cross-module contracts use the cheapest tier that
actually exercises the boundary. “Exhaustive” is a suite name, not a coverage obligation.

Apply the coverage decision to additions and the retirement rules to existing cases.
Keep UI tests only for a **shipping product outcome** that unit/package tests cannot own:

1. **Shell / entry** — a major surface becomes usable (Play chooser, Homestead wallet, Shop controls, Battle chrome).
2. **State-changing journey** — a user action mutates durable or navigable state (shop leave returns to Play, retreat returns to Play, recruit continue).
3. **Safety invariant** — a wrong interaction must not happen (locked slot inert; hand drag must not open detail). **One owner only** across smoke + exhaustive.

Avoid UI tests that mirror incidental copy or chrome, race live ticks during long
detail journeys, or duplicate the same failure mode across smoke and FullUI. A
focused layout or scroll/gesture regression is appropriate when it protects a
consequential outcome, such as reaching a control, that a cheaper tier cannot prove.
Push loadout, party-selection, and unlock rules down to package tests when possible.

**Brittleness:** locate controls by `AccessibilityID` and assert the meaningful
outcome. Avoid incidental display names, rarity labels, or exact scroll geometry;
assert those values only when they are themselves the contract being protected.

Smoke/full-UI class membership and launch details belong to
[`TrinketUITests/README.md`](../../TrinketUITests/README.md); this document owns
only the semantic keep/drop rubric above. Command selection and isolation belong
to [Verification.md](Verification.md).

## UI execution notes

Frame pacing and app-journey metrics are not part of smoke or hosted CI.
Measurement belongs to the [performance playbook](PerformanceInvestigationPlaybook.md).
Launch-arg catalog, speed rules, and mid-battle guidance live in
[`TrinketUITests/README.md`](../../TrinketUITests/README.md); command selection and
isolation belong to [Verification.md](Verification.md).
