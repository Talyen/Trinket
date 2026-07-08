# Unit Test Audit

Goal: Assess the full unit test suite for coverage, quality, speed, duplication, gaps, and 2026 Apple/Swift best practices — then produce a prioritized, actionable improvement plan.

**Last execution (2026-07-07):** Tier 1–3 improvements applied on `cursor/unit-test-audit-fixes-1c5d`. Highlights: `XCTAssertNotNil` eliminated (0 remaining); `BattleSessionTests` split into `BattleSessionAppIntegrationTests`, `BattleSessionSimulationTests`, and `BattleVictorySummaryTests`; shared `AppTestCase` base; Swift Testing parameterized catalog tests; `TrinketDesignSystem` `ExperienceBarTests` + `VisualFoundationTests`; `Task.sleep` replaced with clock polling in tick-loop tests; code coverage enabled on `TrinketTests`; `ci-locally.sh` unit timing budget gate added.

You are working on Trinket, a portrait-first iOS fantasy idle auto-battler (Swift 6 / SwiftUI, iOS 26, swift-tools-version 6.2, Swift 6 strict concurrency enabled). Read `AGENTS.md` and `Docs/Architecture.md` before editing.

## Targets

Extract metrics with these probes:

```bash
# Test inventory by module
echo "=== File counts ==="
for d in TrinketTests Packages/*/Tests; do
  count=$(find "$d" -name '*.swift' ! -path '*/Support/*' ! -name '*TestSupport*' ! -name '*Factory*' | wc -l)
  support=$(find "$d" -name '*.swift' -path '*/Support/*' | wc -l)
  echo "${d}: $count test files + $support support files"
done

echo "=== Size distribution (lines) ==="
find . -name '*.swift' -path '*/Tests/*' -exec wc -l {} + | sort -rn | head -20

# Naming convention compliance
rg -n 'func test\w+' --type swift -g '*Tests/*' --no-filename | \
  sed 's/(.*//' | sort > /tmp/test-names.txt
echo "Tests with 'When' in name: $(rg -c 'test\w+When\w+' /tmp/test-names.txt || echo 0)"
echo "Tests with '_' separator: $(rg -c 'test\w+_\w+' /tmp/test-names.txt || echo 0)"

# Force unwraps and try! in tests
rg -n 'as!|try!' --type swift -g '*Tests/*'
rg -n 'XCTAssertNotNil' --type swift -g '*Tests/*'

# Sleep usage (flaky async tests)
rg -n 'Task\.sleep|usleep|sleep\(' --type swift -g '*Tests/*'

# Timeout-based async tests
rg -n 'expectation\|fulfill\|wait(' --type swift -g '*Tests/*'

# Swift Testing adoption — target 0
rg -n '@Test\|#expect\|#require\|import Testing' --type swift -g '*Tests/*'

# SwiftLint in tests
swiftlint --strict --config .swiftlint.yml --path TrinketTests 2>&1 | tail -5
swiftlint --strict --config .swiftlint.yml --path Packages 2>&1 | tail -5

# Test timing hotspots
./Scripts/test-timing.sh report --top 30
./Scripts/test-timing.sh report --by-class
```

## Checks

### 1. Coverage completeness

#### Module-to-test mapping

Verify each module has adequate unit test coverage. Use the ownership table from `Docs/Architecture.md` and the package test READMEs as the authority:

| Module | Expected minimum coverage targets | Current file count |
|--------|----------------------------------|-------------------|
| `TrinketCore` | Stats rules, progression formulas, effect model, keyword resolution | 8 test files |
| `TrinketContent` | Catalog invariants, ability descriptions, item generation, encounter resolution | 15 test files |
| `BattleEngine` | All effect handlers, pipeline steps, state transitions, simulator, integration wiring | 42 test files |
| `TrinketPersistence` | All `Player*Store` types, save/load roundtrip, migration, sync, sanitizer | 11 test files |
| `TrinketDesignSystem` | Theme rendering, visual style, typography, `ExperienceBar` layout, `Keyword.visualStyle` | 2 test files |
| `Trinket` (app) | `AppState`, `BattleSession`, `OptionsStore`, launch args, audio routing | 15 test files |

**Checks:**

- Identify every `public` or `package` API in each module that lacks a unit test. Focus on:
  - `TrinketDesignSystem` (2 tests is the most glaring gap — likely missing surface chrome, keyword styling, ExperienceBar layout)
  - `TrinketCore` (8 tests — verify all `CombatantProgression` paths, `PrimaryStatsRules` edge cases, and `Keyword` resolution are covered)
- Verify `EffectKind` registry parity: every `EffectKind` case has a test in `EffectHandlersApplyTests` or a dedicated handler test file. Grep:

  ```bash
  rg 'case \w+' --type swift Packages/BattleEngine/Sources/BattleEngine/Effects/EffectKind.swift
  rg 'EffectKind\.' --type swift Packages/BattleEngine/Tests/ | sort -u
  ```
- Check that integration test files (3–6 tests each per `Packages/BattleEngine/Tests/README.md`) have not bloated beyond the thin-integration convention.
- Verify the DoD from `AGENTS.md` is being followed for recent commits (via `git log --oneline -30` — do new features include the required test types?).

### 2. Test quality & assertion style

#### Assert outcomes, not implementation

- Battle tests must assert semantic events (status kinds, milestones, victory/defeat, HP deltas) — not log formatting strings or `ActionEvent` fingerprints.
- Use `BattleEvent` predicates from `BattleTestFixtures` rather than raw string matching on `description`.
- Store tests must follow: mutate → reload from disk → assert. Do not assert on internal cache state or private properties.

#### Strong assertions

- Replace `XCTAssertNotNil(foo)` with `XCTUnwrap(foo)` or `#require(foo)` (in Swift Testing) — exceptions only when the value's existence is not a behavioral contract of the test.
- No "function exists" or "returns defined" tests — every assertion must protect a player-visible or module-contract behavior.
- No empty test methods (`func testFoo() {}`).
- No tests that only call `super.setUp()`.

#### Avoid silent `try?` in tests

- `try?` in tests swallows errors that should cause test failure.
- Use `XCTAssertNoThrow` helpers or `XCTAssertThrowsError` for error-path coverage.
- In Swift Testing, use `#expect(throws:)`.

#### Semantic event assertions over fingerprints

Bad:
```swift
XCTAssertEqual(event.description, "Hero deals 12 damage to Skeleton")
```

Good:
```swift
XCTAssertTrue(events.contains { $0.kind == .damage && $0.actorName == "Hero" })
```

#### UI test quality

- Use `assertExists` with `accessibilityIdentifier` — no existence checks on the app itself or generic containers.
- No debug gestures, hidden buttons, or QA-only toggles in UI tests.
- Prefer `-launch-screen` / `-selectedTab` / `-completed-stages` launch args over tab+grid navigation.

### 3. Swift 6 concurrency hygiene

Swift 6 strict concurrency is enabled on all package targets (`Docs/Architecture.md` § 149). Tests must follow.

#### @MainActor discipline

Test files that touch SwiftUI views, `Observable`/`ObservableObject` types, or persistence stores must be `@MainActor`. The pattern is already established in `TrinketPersistenceTests` and app tests — but verify no test class is missing the annotation where needed.

```bash
# Find test classes that touch MainActor types without annotation
rg -l 'PlayerSaveStore|AppState|BattleSession|@Observable|ObservedObject' \
  --type swift -g '*Tests/*' | while read -r f; do
  head -30 "$f" | rg -q '@MainActor' || echo "MISSING: $f"
done
```

#### Sendable in test helpers

- Shared test fixtures (`AppTestSupport`, `SaveTestSupport`, `CombatantFixtures`) should be `Sendable` if passed across async boundaries.
- Avoid `static var` mutable state in test support files — prefer factory functions.

#### No unawaited Tasks

```bash
rg 'Task\s*\{' --type swift -g '*Tests/*' -A1 | rg -v 'await'
```

Each `Task { }` in test code must be awaited or explicitly detached with a documented reason.

#### Concurrency warnings

Build tests with `SWIFT_STRICT_CONCURRENCY=complete` (already the default per `project.yml`). Flag any test files that suppress concurrency warnings:

```bash
rg 'SWIFT_STRICT_CONCURRENCY|warning.*concurrency' --type swift -g '*Tests/*'
```

### 4. Swift Testing adoption assessment

Swift Testing (`import Testing`) is Apple's first-party testing framework alongside XCTest. It has been generally available since Xcode 16 (2024) and was featured in WWDC26 session #267 "Migrate to Swift Testing". The project currently has **zero** Swift Testing adoption (all 104 test files use XCTest).

Both frameworks coexist in the same target — migration can be incremental.

#### Evaluate migration candidates

| XCTest pattern | Swift Testing replacement | Benefit |
|----------------|--------------------------|---------|
| `XCTUnwrap(try ...)` | `#require(...)` | Fewer `try`/`throws`; richer failure diagnostics |
| `XCTAssertEqual(a, b)` | `#expect(a == b)` | Captures operand values in failure output |
| `XCTAssertTrue(condition)` | `#expect(condition)` | Self-explanatory; no need for message string |
| `func testX() { ... }` | `@Test func x() { ... }` | No class inheritance; no `XCTestCase` base class |
| `class XTests: XCTestCase` | `@Suite struct XTests` | Value types; no `setUp`/`tearDown` boilerplate |
| Catalog loops (for-in) | `@Test(arguments: [...])` | Built-in parameterized tests; per-argument failure isolation |
| `.tags`? Custom enum | `.tags("network", "persistence")` | Built-in tag system; filter in Xcode/CI |

#### High-value migration targets

1. **Catalog invariant tests** (`EnemyCatalogTests`, `AbilityCatalogTests`, `ItemAffixCatalogTests`, etc.) — these loop over content arrays. Swift Testing's `@Test(arguments:)` would give per-item failure isolation and eliminate the loop boilerplate.
2. **Symmetric keyword handler tests** (stun/freeze, burn/poison/bleed) — `@Test(arguments:)` with keyword pairs reduces 3 nearly identical test bodies to 1.
3. **New tests** — write in Swift Testing by default; the test runner discovers `@Suite`/`@Test` markers automatically in the same target as XCTest.

#### Non-goals

- Do not force-migrate existing XCTest files. The cost/benefit favors natural refactoring.
- Do not convert `BattleGoldenPathTests` or other golden-path regression suites — their pattern maps cleanly to XCTest.
- Do not add Swift Testing as a dependency until Xcode project integration is tested (Swift Package Manager integration is seamless; verify Xcode test plans discover `@Test` functions).

#### Update test plans

Ensure `Unit.xctestplan` and `Integration.xctestplan` do not opt out of Swift Testing discovery. Swift Testing tests are discovered automatically when `import Testing` is present — no test plan change required unless using custom filters.

```bash
# Verify no test plan explicitly excludes Swift Testing
rg -i 'testing|swift.testing' --type xml -g '*.xctestplan'
```

### 5. Test speed & efficiency

#### Measure baseline

```bash
./Scripts/test.sh unit 2>&1 | tail -3
./Scripts/test-timing.sh report --last 5
```

Current unit test suite runs in ~40s wall time (from timing log). Targets:
- 🌿 **Green:** < 60s (CI-friendly)
- 🟡 **Yellow:** 60–120s (acceptable, monitor)
- 🔴 **Red:** > 120s (needs intervention)

#### Identify hotspots

```bash
./Scripts/test-timing.sh report --top 30 --by-class
```

Flag any test method exceeding 1 second wall time (unit tests should be sub-second). Exception: integration tests that tick through multiple battle rounds.

#### Async anti-patterns

- No `Task.sleep` for delays — inject short intervals into production initializers instead.
- No `XCTestExpectation` with multi-second `wait(timeout:)` — if you see timeouts > 2s, redesign the async seam.
- Use `XCTestCase` `fulfillment(of:timeout:)` with the minimum viable timeout.

#### UI test speed

- Prefer `-launch-screen` / `-selectedTab` deep links over tap-based navigation.
- Avoid `assertExistsAfterScroll` for far-off Play map nodes; use `-completed-stages` or `-map-scroll-target`.
- Use search field `replaceText` instead of long grid scroll loops.
- UI tests run with `-parallel-testing-enabled NO` in `Scripts/test.sh`; check `smoke` wall time stays near ~2 min.

### 6. Duplication and overlap

#### Setup duplication

Flag test files that repeat identical `setUp` logic:

```bash
# Extract setUp blocks and compare
rg -A 10 'override func setUp' --type swift -g '*Tests/*' | \
  rg -v '^--$' | rg '(UUID|temp|directory|UserDefaults|suiteName)' | \
  sort | uniq -c | sort -rn | head -15
```

Patterns to watch for:
- Every `AppStatePlayFlowTests` and `AppStateTests` test re-creates `AppTestSupport.makeAppState(...)`. Extract to a shared base class or a `makeSUT()` factory.
- `BattleSessionTests` (684 lines) manages its own temp directory manually instead of using `SaveTestSupport`.
- `BattleEngineTests` has multiple files (e.g., `CombatPipelineTests.swift` at 405 lines) that build `BattleEngineContext` by hand — use `BattleStateTestFactory` + `EffectHandlersTestSupport` helpers instead.

#### Overlapping test coverage

- Integration test files (`ControlMeterIntegrationTests`, `CleanseIntegrationTests`, etc.) should have 3–6 tests each. Flag any file exceeding 10 tests — the coverage likely belongs in a focused handler test.
- Catalog loop tests should live in `TrinketContentTests` (e.g., `EnemyCatalogTests`, `AbilityCatalogTests`) — not duplicated in app tests or other packages.
- No test file should duplicate content invariant checks that already exist in a `*CatalogTests` file.

#### Orphaned or copy-pasted tests

- Every test file should map to a production source file or concept.
- Remove test files for deleted or renamed production code.
- No commented-out test methods — delete or uncomment.
- No test files with `import XCTest` but zero `func test` methods.

### 7. Gaps identification

#### Per-module gap analysis

| Module | Current tests | Likely gaps |
|--------|--------------|-------------|
| `TrinketDesignSystem` | `PaletteTests`, `KeywordVisualStyleTests` (2 files) | Missing: surface chrome (`SurfaceRole`, `BackgroundMode`), `ExperienceBar` rendering, typography scaling, `HomesteadTint` colors, dark/light mode consistency |
| `TrinketCore` | `CombatantProgressionTests`, `EffectModelTests`, `EffectPresentationTests`, `ExperienceScalingTests`, `KeywordCoreTests`, `PrimaryStatsModelTests`, `PrimaryStatsRulesTests`, `StatGrowthTests` (8 files) | Missing: `Effect` value semantics / equatable / Codable roundtrip; boundary cases for progression level 0, max level, negative XP; invalid stat combinations in `PrimaryStats` |
| `TrinketContent` | 15 catalog + generator files | Likely well-covered (catalog invariants, generation). Check that every new content type (affix, item base, ability, enemy) added in the last 3 commits has a corresponding invariant test. |
| `BattleEngine` | 42 files | Most thorough coverage. Check: new `EffectKind` not yet in `EffectHandlersApplyTests`; new mechanic leaks without integration test; `BattleSimulator` error paths |
| `TrinketPersistence` | 12 store + roundtrip files | Check: save corruption recovery, concurrent write contention, migration from prior save versions, empty save edge case |
| `Trinket` (app) | 15 files | Check: `BattleVictorySummary` logic, `EncounterLevelResolver` edge cases, music director state machine transitions, deep-link arg parsing for all 5 tabs |

#### Gaps from AGENTS.md Definition of Done

For recent commits (check `git log --oneline -30 -- ':(exclude)*.md' ':(exclude)*.tsv' ':(exclude)Scripts/*'`):

1. Rules/models → at least one focused unit test in the owning package?
2. New `Player*Store` API → write-through persistence test in `TrinketPersistenceTests`?
3. New catalog content → invariant test in `*CatalogTests`?
4. New `EffectKind` → registry parity test + `EffectHandlersApplyTests`?
5. New app orchestration → focused `TrinketTests` test?
6. New user flow → `accessibilityIdentifier` + one smoke UI test?

#### Specific edge-case gaps to check

```bash
# Empty/null/zero cases
rg 'func test\w+' --type swift -g '*Tests/*' | rg -i 'empty\|null\|nil\|zero\|none\|invalid\|unknown\|negative\|max\|min\|boundary'
# This should return at least 1 test per module — flag modules with 0 matches

# Error path tests
rg 'func test\w+' --type swift -g '*Tests/*' | rg -i 'error\|fail\|corrupt\|invalid\|missing\|broken\|malformed'
```

### 8. Apple/Swift best practices

#### Arrange-Act-Assert (AAA)

Every test method should follow a clear AAA structure visually separated by blank lines:

```swift
// Arrange
let sut = makeSUT()
let input = fixtureData()

// Act
let result = sut.process(input)

// Assert
XCTAssertEqual(result, expected)
```

Spot-check 10 random test files for AAA compliance. Flag files where arrangement is interleaved with assertion or lacks clear grouping.

#### System under test (SUT) naming

- Use `sut` or `subject` as the variable name for the object under test — not domain-specific names that vary per test.
- Extract `makeSUT()` factory methods for reuse across tests in the same file.

#### Test isolation

- No `static var` mutable state shared between tests (check all test support files).
- Each test should create its own copy of the system under test — no shared mutable fixtures.
- Verify teardown properly cleans up temp directories, user defaults suites, and in-memory stores.

#### Naming convention

Enforce `test<Behavior>When<Condition>` across all test files. Flag files using `test<Condition>()` (missing behavior) or `testX_Y_Z` (underscore separator).

Examples of compliant names:
```swift
func testStartBattleConfiguresActiveBattle()
func testCompleteActiveBattleIsIdempotentWhenContinueTappedTwice()
```

#### Edge case coverage

Every `public` function that accepts numeric inputs should have tests for:
- Zero
- Negative values (if unsigned, document why)
- Maximum/overflow boundary
- Empty collections
- Invalid/missing IDs

#### Error path coverage

Every `throws` function should have at least one test exercising the failure path, unless the function is `rethrows` forwarding from a caller test.

#### Determinism

- All battle tests must use `BattleStateTestFactory.makeBattle(seed: 0)` — no raw `BattleState(...)` constructors.
- Non-battle RNG tests (item generation, encounter selection) must accept an injected `RandomNumberGenerator` and test with a fixed seed.
- Verify no unseeded `random()`, `randomElement()`, or `shuffle()` calls in production code used by tests (see `Docs/Audits/SideEffectSurfaceAudit.md`).

### 9. Coverage infrastructure

#### Enable code coverage

Check whether code coverage data collection is enabled:

```bash
xcodebuild -showBuildSettings -project Trinket.xcodeproj -scheme TrinketTests 2>/dev/null | \
  rg -i 'GCC_INSTRUMENT_PROGRAM_FLOW_ARCS|GCC_GENERATE_TEST_COVERAGE_FILES|CLANG_COVERAGE_MAPPING|ENABLE_CODE_COVERAGE'
```

If coverage is not enabled:
- Add `GCC_INSTRUMENT_PROGRAM_FLOW_ARCS = YES` and `GCC_GENERATE_TEST_COVERAGE_FILES = YES` to the test build configuration, or use XcodeGen settings in `project.yml`.
- Add a CI gate: `--minimum-coverage 70%` for packages, 50% for app target (or derive from current baseline).
- Do **not** mandate 100% coverage — target the 80/20 rule: 80% coverage on critical paths (battle rules, persistence, progression) is sufficient.

#### Coverage targets by module tier

| Tier | Module | Minimum coverage target |
|------|--------|------------------------|
| 1 | `BattleEngine`, `TrinketPersistence` | ≥ 80% |
| 2 | `TrinketCore`, `TrinketContent` | ≥ 70% |
| 3 | `Trinket` (app), `TrinketDesignSystem` | ≥ 50% (UI-heavy) |

#### Profile slow coverage builds

If coverage slows the test suite significantly, use the `.xctestplan` option `codeCoverageTargets` to scope it to specific targets rather than the whole app.

### 10. SwiftLint for tests

Verify lint rules apply to test code without blanket suppressions:

```bash
swiftlint --strict --config .swiftlint.yml --path Packages/BattleEngine/Tests 2>&1 | rg -c 'Error:'
```

Check for:
- `// swiftlint:disable` in test files — each should have a documented inline reason (e.g., `// swiftlint:disable:next force_cast` with a comment).
- Files exceeding `file_length` (550 warning / 750 error) or `type_body_length` (350 / 500). Current known offenders: `BattleSessionTests.swift` (684 lines), `CombatPipelineTests.swift` (405), `BattleStateTests.swift` (340), `EffectHandlersApplyTests.swift` (312).

### 11. Prioritized improvement plan

Organize findings into three tiers. The agent executing the audit should populate specific file:line references and current metrics.

*Tip: You can identify missing test companion files automatically by running a script that matches files in the production source directory against files in the test directory (e.g., comparing files in `Trinket/Features/` with `TrinketTests/Features/` and flagging mismatches).*

#### Tier 1 — High impact, low effort (quick wins)

| Issue | Expected fix | Example locations |
|-------|-------------|-------------------|
| `XCTAssertNotNil` → `XCTUnwrap` | Mechanical rename; safer assertions | All test files |
| Silent `try?` in tests | Replace with `XCTAssertNoThrow` | [BattleSessionTests.swift](../../TrinketTests/Battle/BattleSessionTests.swift), [AppStatePlayFlowTests.swift](../../TrinketTests/App/AppStatePlayFlowTests.swift) |
| Orphaned `// swiftlint:disable` | Remove or add inline reason | [BattleSessionTests.swift:8](../../TrinketTests/Battle/BattleSessionTests.swift#L8) |
| Missing `@MainActor` on store tests | Add annotation | TrinketPersistence tests |
| `Task.sleep` in tests | Replace with injected short interval | Search results |
| Catalog loop tests not using `@Test(arguments:)` | Migrate to Swift Testing | [EnemyCatalogTests.swift](../../Packages/TrinketContent/Tests/TrinketContentTests/EnemyCatalogTests.swift), [AbilityCatalogTests.swift](../../Packages/TrinketContent/Tests/TrinketContentTests/AbilityCatalogTests.swift) |

#### Tier 2 — Medium impact, medium effort

| Issue | Expected fix | Example locations |
|-------|-------------|-------------------|
| `TrinketDesignSystem` test gap (2 files only) | Add tests for surface views, `ExperienceBar` | [Packages/TrinketDesignSystem/Tests/](../../Packages/TrinketDesignSystem/Tests/) |
| Setup duplication across `App*Tests` | Extract shared `makeSUT` base or support | [AppStateTests.swift](../../TrinketTests/App/AppStateTests.swift), [AppStatePlayFlowTests.swift](../../TrinketTests/App/AppStatePlayFlowTests.swift) |
| `BattleSessionTests.swift` 684 lines | Split into focused test files by concern | [BattleSessionTests.swift](../../TrinketTests/Battle/BattleSessionTests.swift) |
| Right-size integration test files (target 3–6 tests) | Move extra tests to focused handler tests | `StatIntegrationTests`, `AbilityEffectIntegrationTests` |
| UI test flakiness in `BattleFlowUITests` | Add retry or redesign entry path | [BattleFlowUITests.swift](../../TrinketUITests/Battle/BattleFlowUITests.swift) |
| `CombatPipelineTests.swift` hand-builds `BattleEngineContext` | Refactor to use `BattleStateTestFactory` | [CombatPipelineTests.swift](../../Packages/BattleEngine/Tests/BattleEngineTests/CombatPipelineTests.swift) |

#### Tier 3 — Lower impact, higher effort (strategic)

| Issue | Expected fix | Example locations |
|-------|-------------|-------------------|
| Swift Testing incremental migration | New tests in Swift Testing; migrate catalog loops first | All modules |
| Code coverage infra + CI gate | Enable coverage, set minimums, add to CI | [project.yml](../../project.yml), [ci-locally.sh](../../Scripts/ci-locally.sh) |
| `TrinketCore` edge case coverage gaps | Add boundary/zero/negative tests | [PrimaryStatsRulesTests.swift](../../Packages/TrinketCore/Tests/TrinketCoreTests/PrimaryStatsRulesTests.swift), [CombatantProgressionTests.swift](../../Packages/TrinketCore/Tests/TrinketCoreTests/CombatantProgressionTests.swift) |
| Test timing budget (target <60s unit, <3m smoke) | Profile top 10 hotspots, eliminate sleeps, parallelize package tests | Run `test-timing.sh` |
| No AAA pattern in legacy test files | Refactor for readability during other edits (not wholesale) | Oldest test files |

## Verification

After making changes identified by this audit, run:

```bash
# Generate (if manifests changed)
./Scripts/generate.sh

# Lint tests specifically
swiftlint --strict --config .swiftlint.yml --path TrinketTests
swiftlint --strict --config .swiftlint.yml --path Packages

# Unit tests (full, unfiltered)
./Scripts/test.sh unit

# Boundary check
./Scripts/check-module-boundaries.sh

# If UI changes touched identifiers
./Scripts/test.sh smoke

# Timing check
./Scripts/test-timing.sh report --last 1
./Scripts/test-timing.sh assert-budget --mode unit --max-wall 60 --skip-if-missing
```

## Cross-reference

- `Docs/Audits/TestQualityAudit.md` — standing conventions for assertion style, fixture reuse, speed hygiene, and DoD alignment. This audit extends that baseline with coverage, concurrency, Swift Testing, and gap analysis.
- `Docs/Audits/BehaviorHardeningAudit.md` — persistence, async, idempotency checks that complement test coverage.
- `Docs/Audits/SideEffectSurfaceAudit.md` — determinism and RNG discipline in tests.
- `AGENTS.md` § Unit Tests — approved conventions, test ownership, DoD.
- `Packages/BattleEngine/Tests/README.md` — test ownership matrix and integration file conventions.
