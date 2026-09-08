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

Prefer `TrinketTestSupport` (`CombatantFixtures`, `ItemFixtures`, battle parties) for shared fixtures; `BattleStateTestFactory` owns `BattleState` construction in `BattleEngineTests` and `BattleTestFixtures` owns only play helpers (`playFirstPlayableCard`, `endTurn`). Save harnesses live
in `TrinketPersistence`'s `TrinketPersistenceTestSupport` target—not in `TrinketTestSupport`—so TestSupport stays
Persistence-free. App suites use `AppTestContext`; Persistence uses
`PersistenceTestContext`. Canonical RNG seed is `CombatantFixtures.deterministicBattleSeed` (1772). Package-specific fixture, RNG, and handler-dispatch
conventions belong in the owning package's test README; do not duplicate them
here.

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
- **Do not unit-test:** log prose (except a few representative formatter cases), `TrinketDesign` styling, AVFoundation playback, real CloudKit I/O, BattleFeature layout/glyph/dissolve/recipe chrome.

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

Extend the existing semantic matrix, journey, method, or file first. Add a new
owner only when the behavior cannot fit coherently in an existing one. Prefer
adding a declaration over a new file or class. Remove or merge coverage made redundant by the change. Do not test plumbing, in-memory stored-property round trips, display copy, layout constants, framework behavior, or trivial delegation.

**Likely owners when the gate passes:** rules/models → owning package; persistence semantics → existing store/sanitizer journey; catalog content → invariant matrix, not exact-count snapshots; novel `EffectKind` behavior → existing registry/handler matrix; consequential app transitions that packages cannot own → `TrinketAppStateTests`.

New user flows still need a stable `AccessibilityID` selector (or an existing appropriate one), but add or extend a UI test only when the keep/drop rubric below applies. Prefer a coherent existing smoke/exhaustive journey over a new class; assert visible outcomes, not custom accessibility prose. Per PD-014, assertions may rely on identifiers and hittability only; accessibility wording is not a stable test contract.

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
Homestead/Play presentation contract is not style-only. Run the path-scoped
handoff and complete every routed package, compile, and smoke step. The
classifier owns the exact route; do not stop after style. Stable identifiers
must be applied at the modifier that remains visible to XCUITest (for example,
the shared glass CTA modifier).

Command routing, isolation, and mid-task `--no-build` live in
[Verification.md](Verification.md).

## UI keep / drop rubric

UI tests selectively prove critical journeys and interaction wiring once; battle
rules belong in package tests, and cross-module contracts use the cheapest tier that
actually exercises the boundary. “Exhaustive” is a suite name, not a coverage obligation.

Apply the coverage decision to additions and the retirement rules to existing cases.
Keep UI tests only for a **shipping product outcome** that unit/package tests cannot own:

1. **Shell / entry** — a major surface becomes usable (Play chooser, Homestead wallet, Shop controls, Battle chrome).
2. **State-changing journey** — a user action mutates durable or navigable state (shop leave returns to Play, retreat returns to Play, recruit continue).
3. **Safety invariant** — a wrong interaction must not happen (locked slot inert; hand drag must not open detail). **One owner only** across smoke + exhaustive.

Do **not** UI-test (delete or never add): marketing/copy strings, nav titles, unexpected-text catalogs, layout/chrome mirrors (overscroll, swipe scroll ownership, grid layout), mid-battle detail marathons that race live ticks, or second copies of the same interaction across smoke and FullUI. Push loadout, party-selection, and unlock rules down to package tests when possible; UI proves the sheet/control path once.

**Brittleness:** assert `AccessibilityID` plus one visible outcome (exists / dismissed / tab returned). Never pin display names, rarity labels, or scroll geometry unless that string is the product contract.

Smoke/full-UI class membership and launch details belong to
[`TrinketUITests/README.md`](../../TrinketUITests/README.md); this document owns
only the semantic keep/drop rubric above. Command selection and isolation belong
to [Verification.md](Verification.md).

## UI execution notes

Frame pacing and app-journey metrics are not part of smoke or hosted CI. Use the
performance playbook for the exclusive matrix, focused harness iteration, and
Instruments evidence. Full layout, launch-arg catalog, speed rules, and
mid-battle guidance live in [`TrinketUITests/README.md`](../../TrinketUITests/README.md).
