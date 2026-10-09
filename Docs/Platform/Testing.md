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
- **Async/debounce:** inject short intervals in production inits; poll in tests — never `Task.sleep` for multi-second production delays.
- **Events:** pin outcome counters; assert event *semantics*, not full log fingerprints.
- **Tier fit:** Keep package tests deterministic and credential-free; real CloudKit I/O and physical audio playback need integration/device evidence. Presentation logic can merit unit coverage for consequential contracts such as finite geometry, interruption continuity, and resource cleanup; apply the coverage decision below.

## Coverage decision (new and changed behavior)

Maintain the smallest test portfolio that provides strong confidence in consequential
game behavior and development safeguards. Default to no new test. Add or expand
coverage for **high marginal value**: substantial protection beyond what existing
assertions already prove. This standard applies equally to package, script, and
UI/e2e tests, including extra assertions and parameterized cases in existing tests.

| Value | Definition | Default |
|---|---|---|
| High | Detects a credible, materially harmful failure that existing coverage would miss, with reliable assertions and proportionate cost. | Add or strengthen the smallest suitable owner. |
| Medium | Protects useful but limited behavior, has modest additional detection value, or costs substantially more than the protection warrants. | Retire or skip; exceptions are limited to specifically justified readability or diagnostic evidence. |
| Low | Duplicates protection, mirrors implementation, checks trivial plumbing, or asserts incidental details without a meaningful failure outcome. | Do not add. |

Save loss, duplicated rewards, incorrect battle resolution, blocked progression,
and purchase-access failures are strong candidates, not automatic qualifications.
A tiny assertion can be high value; a previously reported bug can still yield a
low-value test. Cheap execution, a distinct branch, public API status, or increased
coverage percentage does not independently justify coverage.

Before authoring, name the credible harmful failure, inspect existing assertions
rather than relying on test names or search pointers, and choose the cheapest tier
that actually detects it. Add or expand coverage only when all are true:

1. The change introduces or repairs a distinct, consequential behavior or invariant.
2. Existing assertions do not already prove the changed behavior or invariant.
3. The proposed assertion would fail before the fix, except for genuinely new behavior.
4. The cheapest suitable tier can express it without duplicating a stronger owner.
5. Its added confidence meets the high-value threshold after accounting for runtime,
   setup, brittleness, and maintenance, or merits a rare medium-value exception.

When adding coverage, briefly explain the harmful outcome and existing coverage
gap in the handoff. For a medium-value exception, also give a concrete readability
or diagnostic reason it merits ongoing automated protection despite its limited value or cost. This is a
judgment to explain, not a separate approval checkpoint; no value labels or
manifests are required. Strengthening existing assertions, adding no test, and
retiring weak coverage are successful outcomes.

Prefer shared invariants, representative behavior families, and meaningful boundaries.
Representative cases should distinguish materially different failure modes, not
repeat the same proof with different names or inputs.
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
Assess directly related cases against the value rubric, without expanding a routine
change into a repository-wide pruning pass. Low- and medium-value coverage is a
retirement candidate, not an automatic deletion: inspect what it actually protects
and preserve effective consequential evidence and required release journeys.
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
