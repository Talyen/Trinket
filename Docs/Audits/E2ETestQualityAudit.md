# E2E / Integration Test Quality & Speed Audit (2026)

Goal: Produce a detailed, prioritized improvement plan for the e2e/integration test suite — covering coverage, appropriateness, quality, speed, duplication, gaps, and alignment with Apple/Swift 2026 best practices. Every finding must include a concrete remediation, estimated effort, and projected speed/quality impact.

Point-in-time audit snapshot. Use the agent prompt below to task a coding agent with one focused audit pass. Do not treat this as standing product requirements unless explicitly cited.

References: `AGENTS.md` § Unit Tests / UI Tests, `Docs/Audits/TestQualityAudit.md` (existing style guide), `Packages/BattleEngine/Tests/README.md` § test ownership.

## Agent prompt

Copy everything between the markers into a new agent session:

```text
--- BEGIN E2E TEST QUALITY AUDIT TASK ---

You are working on Trinket, a portrait-first iOS fantasy idle auto-battler (Swift 6 / SwiftUI, iOS 26). Read `AGENTS.md` and `Docs/Architecture.md` before editing.

**Mission:** Run all seven probe groups below against the Trinket test suite. For each finding, assign a priority score and write a remediation paragraph. Deliver the complete improvement plan as a Markdown table at the end.

**Hard stops**
- Do not read every file — run the probes, triage the output, produce the plan. No file-by-file browsing.
- Do not change any test code. This audit is diagnostic only — produce the plan, do not execute it.
- Do not touch `Docs/Roadmap.md`, `ContentManifest/`, `Assets.xcassets`, `Resources/`, `.DerivedData/`, or `Generated/*`.
- Do not suggest changing `BattleStateTestFactory.makeBattle(..., rngSeed: 0)` determinism.
- Do not suggest removing `accessibilityIdentifier` values used in `TrinketUITests`.
- Do not suggest third-party test dependencies (Quick, Nimble, etc.).
- Do not suggest changes to `project.yml` scheme / test-plan configuration.
- Do not suggest adding CI platform code (GitHub Actions, etc.) unless explicitly asked.
- XCTest must remain for UI automation tests (`XCUIApplication`, `XCUIElement`) and performance tests (`XCTMetric`). Only recommend migration to Swift Testing for unit/integration tests (app + package).

**Workflow**

1. For each probe group, run the bash commands and collect output.
2. Score each finding using the scoring rubric.
3. Write a one-paragraph remediation for each finding.
4. After all probes, produce the consolidated improvement plan table.
5. Verify the plan has no self-conflicting recommendations.

---

## Probe Group 1: Framework & Migration Baseline

Purpose: Inventory the existing test suite by testing framework (Swift Testing vs XCTest), tier, and ownership domain.

```bash
# Count XCTest test classes
rg -c 'class \w+:\s*XCTestCase' --type swift TrinketUITests/ TrinketTests/ Packages/ 2>/dev/null | sort -t: -k2 -rn

# Count Swift Testing test suites (@Test attribute)
rg -c '@Test' --type swift TrinketTests/ Packages/ 2>/dev/null | sort -t: -k2 -rn

# Count UIKit imports (new projects should prefer SwiftUI testing)
rg -n 'import UIKit' --type swift -g '*Tests*' 2>/dev/null

# Find setUp / tearDown patterns (Swift Testing uses init/deinit)
rg -n 'override func setUp' --type swift -g '*Tests*' -g '!*UITests*' 2>/dev/null

# Find XCTAssert* usage (should be #expect / #require)
rg -n 'XCTAssert' --type swift -g '*Tests*' -g '!*UITests*' 2>/dev/null | head -50

# Find XCTUnwrap (should be #require)
rg -n 'XCTUnwrap' --type swift -g '*Tests*' 2>/dev/null

# Find for-in loops that might be parameterized tests
rg -n 'for \w+ in \[|for \w+ in \w+\.allCases' --type swift -g '*Tests*' 2>/dev/null | head -20

# Find test naming patterns (should not need "test" prefix in Swift Testing)
rg -n 'func test\w+' --type swift -g '*Tests*' -g '!*UITests*' 2>/dev/null | head -30

# Find @MainActor class test suites (struct preferred in Swift Testing)
rg -n '@MainActor\s+.*class.*Test' --type swift -g '*Tests*' 2>/dev/null
```

For each XCTest file, assign a migration complexity:
- **Simple** (≤3 test methods, no async, no custom base class)
- **Medium** (4-10 test methods, shared fixtures, async)
- **Complex** (>10 methods, custom base class, complex async, file-scoped state)

Produce a table: `| File | Framework | Tests | Migrate Cost | Notes |`

---

## Probe Group 2: Speed & Efficiency

Purpose: Identify the slowest tests, the most common speed anti-patterns, and opportunities to parallelize.

```bash
# Run timing report
./Scripts/test-timing.sh report --top 30 --by-class

# Find Task.sleep (never acceptable in tests — use injectable intervals)
rg -n 'Task\.sleep\|sleep(' --type swift -g '*Tests*' 2>/dev/null

# Find waitForExistence with timeouts >3s (should be 1-2s for most elements)
rg -n 'waitForExistence\(timeout: [3-9]' --type swift -g '*UITests*' 2>/dev/null

# Find assertExistsAfterScroll (slower than deep-link navigation)
rg -n 'assertExistsAfterScroll' --type swift -g '*UITests*' 2>/dev/null

# Find UI navigation without deep links (tab -> grid -> tap instead of -launch-screen)
rg -n 'tabBar\.\|\.tap\(\).*\|openStage\|openHeroesCategory' --type swift -g '*UITests*' 2>/dev/null | head -20

# Find UI iteration patterns that should be parameterized tests
rg -n 'for \w+ in' --type swift -g '*UITests*' 2>/dev/null

# Count tests per UI class — classes with 1 test and 1 assertion may not justify the simulator launch cost
rg -c 'func test' --type swift -g '*Smoke*' 2>/dev/null
rg -c 'func test' --type swift -g '*UITests*' -g '!*Smoke*' 2>/dev/null
```

Speed budget reference (Apple recommended, 2026):
| Tier | Current budget | 2026 target | Rationale |
|------|---------------|-------------|-----------|
| `test.sh unit` | 300s | 180s | Swift Testing parallel-by-default + package parallelism |
| `test.sh smoke` | 360s | 240s | Deep-link navigation + fewer redundant simulator launches |
| `test.sh ui` | 720s | 480s | Focused exhaustive tests × smarter configs |

---

## Probe Group 3: Assertion & Quality

Purpose: Audit assertion quality against 2026 Apple best practices.

```bash
# Assert on existence of generic containers (should use specific accessibilityIdentifier)
rg -n 'XCTAssertTrue.*\.exists\|XCTAssertTrue.*\.isHittable' --type swift -g '*Tests*' 2>/dev/null | head -20

# Assert on implementation details instead of semantics
rg -n '"Stage ' --type swift -g '*Tests*' 2>/dev/null | head -10

# No-trivial-assertion violations
rg -n 'XCTAssertNotNil' --type swift -g '*Tests*' 2>/dev/null

# Empty test methods
rg -B1 'func test\w+\(\)\s*\{\s*\}' --type swift -g '*Tests*' 2>/dev/null

# Commented-out test methods
rg -n '//\s*func test\|//\s*@Test' --type swift -g '*Tests*' 2>/dev/null

# for-in loops inside @Test (should be @Test(arguments:))
rg -n '@Test\s*\n.*for \w+ in' --type swift -g '*Tests*' 2>/dev/null

# #available instead of @available on tests
rg -n '#available.*\*\).*return\|guard #available' --type swift -g '*Tests*' 2>/dev/null
```

Quality checklist per test file (score 0-10):
- Uses `#expect` / `#require` (Swift Testing) or `XCTAssert*` with semantic predicates (XCTest)
- Tests one behavior per test function
- No hardcoded timeouts (uses injectable intervals)
- Uses page objects in UI tests
- Every element has a unique `accessibilityIdentifier`
- Test names describe behavior, not implementation
- No for-in loops (uses parameterized tests where applicable)
- Async tests use swift-concurrency patterns, not expectations
- No stale comments or disabled tests without `.bug(...)` trait
- Shared fixtures extracted to support helpers

---

## Probe Group 4: Duplication & Overlap

Purpose: Find tests exercising the same code paths at different tiers.

```bash
# Smoke tests — count assertions per class (identify near-empty smoke tests)
for f in TrinketUITests/Smoke/*.swift; do
  tests=$(rg -c 'func test' "$f" 2>/dev/null || echo 0)
  assertions=$(rg -c 'assert\|XCTAssert\|#expect' "$f" 2>/dev/null || echo 0)
  echo "$f: $tests tests, $assertions assertions"
done

# Exhaustive UI tests
for f in TrinketUITests/Battle/*.swift TrinketUITests/Collection/*.swift TrinketUITests/Search/*.swift; do
  tests=$(rg -c 'func test' "$f" 2>/dev/null || echo 0)
  assertions=$(rg -c 'assert\|XCTAssert\|#expect' "$f" 2>/dev/null || echo 0)
  echo "$f: $tests tests, $assertions assertions"
done

# Unit tests checking same model as UI tests
rg -n 'BattleVictorySummary\|BattleSession\.outcome' --type swift -g '*Tests*' 2>/dev/null

# Catalog invariants duplicated across test targets
rg -n 'uniqueIDs\|ID.*duplicate\|\.allCases\|allIDs' --type swift -g '*Tests*' 2>/dev/null
```

Smoke → exhaustive → unit overlap matrix: for each major feature (Play, Battle, Collection, Search, Options, Homestead), list which tier covers it and whether lower-tier tests duplicate higher-tier coverage.

---

## Probe Group 5: Coverage Gaps (Xcode 26 / 2026 Best Practices)

Purpose: Identify test types missing from the suite that are now recommended.

```bash
# Accessibility audit tests (new in WWDC25)
rg -n 'performAccessibilityAudit\|accessibilityAudit' --type swift 2>/dev/null

# Hitch/performance UI tests
rg -n 'XCTHitchMetric\|measure\(metrics:\|measure\(' --type swift 2>/dev/null

# Runtime API checks / Thread Performance Checker
rg -n 'Thread Performance Checker\|runtime.*check\|CLOSE_ENOUGH' --type swift -g '*Tests*' 2>/dev/null

# URL scheme / deep-link UI tests
rg -n 'app\.open\|XCUIDevice.*open\|launchURL\|openURL' --type swift -g '*UITests*' 2>/dev/null

# Multi-configuration test plans (locales, Dark Mode, Dynamic Type)
rg -n 'locale\|language\|region\|DarkMode\|dark.*mode\|Dynamic Type\|AX.*contentSize' --type swift -g '*Test*' 2>/dev/null

# Confirmation pattern (Swift Testing callback counting)
rg -n 'Confirmation\|confirmation' --type swift 2>/dev/null

# withKnownIssue for known failures
rg -n 'withKnownIssue\|knownIssue' --type swift 2>/dev/null

# .serialized trait (identify tests that can't run in parallel)
rg -n '\.serialized\|\.serial' --type swift 2>/dev/null

# tags usage for cross-file organization
rg -n '\.tags\(' --type swift 2>/dev/null

# CustomTestStringConvertible for readable parameterized test descriptions
rg -n 'CustomTestStringConvertible' --type swift 2>/dev/null

# Background/foreground lifecycle tests
rg -n 'background\|foreground\|\.state == \.running' --type swift -g '*UITests*' 2>/dev/null

# Error state / offline tests
rg -n 'disconnect\|offline\|noConnection\|network.*error\|simulateNetwork\|simulate.*fail' --type swift -g '*Tests*' 2>/dev/null
```

---

## Probe Group 6: Tier Appropriateness & Run Timing

Purpose: Validate each test is in the correct tier and pipeline position.

Audit each test file against the 2026 run-timing matrix:

| Tier | What goes here | When to run | Max duration |
|------|---------------|-------------|-------------|
| **Swift Unit** (`test.sh unit`) | Model rules, state transitions, effect handlers, formatters, persistence read/write, content invariants | Every commit | 120s |
| **Package Unit** (`test-package.sh`) | Deep battle mechanics, complex state machines, simulator determinism, balance sweeps | Every commit (parallel) | 180s |
| **Smoke UI** (`test.sh smoke`) | One assertion per tab/screen that the view loads + critical element exists | Every push | 240s |
| **Full UI** (`test.sh ui`) | Multi-step player journeys (battle victory → reward → collection → equip → battle again) | Pre-merge / nightly | 480s |
| **Accessibility Audit** | `performAccessibilityAudit()` on every screen | Nightly | 60s |
| **Performance** | `XCTHitchMetric` scroll tests, launch-time measurement | Nightly | 120s |
| **Multi-Config** | Smoke tests replayed across 3 locales × 2 devices × Dark/Light mode | Pre-release | 300s |

Check each UI test file:
- Does it use `TestLaunchArg.allForScreen()` instead of navigating from the Play screen? If not, it's slower than necessary and should be flagged.
- Does a smoke test assert more than 3 things? It should be an exhaustive test, not smoke.
- Does an exhaustive test overlap entirely with a smoke test for the same screen? Flag as duplicate.
- Does a unit test spin up the full app? Flag for reduction to focused, injectable dependencies.

---

## Probe Group 7: Parallel & Concurrency Safety

Purpose: Identify tests that block parallel execution or have unsafe shared state.

```bash
# Swift Testing parallel-by-default: find test files with shared mutable state
rg -n 'static var\|static let.*=.*\[.*\]' --type swift -g '*Tests*' 2>/dev/null | head -20

# XCTest files with continueAfterFailure = false (redundant in Swift Testing — #require handles this)
rg -n 'continueAfterFailure\s*=' --type swift -g '*Tests*' 2>/dev/null

# Tests that modify global/UserDefaults state without cleanup
rg -n 'UserDefaults\|\.standard\|NSUserDefaults' --type swift -g '*Tests*' 2>/dev/null | head -10

# FileManager / temp directory cleanup
rg -n 'FileManager\|\.removeItem\|temporaryDirectory' --type swift -g '*Tests*' 2>/dev/null | head -10

# Test isolation — files that use shared singletons
rg -n 'shared\b|\.default\b|\.current\b' --type swift -g '*Tests*' 2>/dev/null | head -20
```

---

## Scoring Rubric

| Score | Criteria |
|-------|----------|
| **P0** | Blocks CI, causes false failures, Swift 6 concurrency violation, tests crash at runtime |
| **P1** | ≥30s per-run savings, eliminates flaky test class, migrates complex XCTest → Swift Testing |
| **P2** | Improves coverage of critical player path, fills gap in test tier matrix |
| **P3** | Best-practice alignment (tags, suite org, page-object consistency, assertion quality) |
| **P4** | Nice-to-have (CustomTestStringConvertible, Confirmation, withKnownIssue for expected failures) |

---

## Verification

After producing the plan:
1. Confirm no recommendations conflict with `Docs/Audits/TestQualityAudit.md`
2. Confirm no recommendation removes an `accessibilityIdentifier` used in UI tests
3. Confirm no recommendation weakens battle determinism (`rngSeed: 0`)
4. Confirm all recommendations are within scope (diagnostic only, no code changes)
5. Write the plan as a single Markdown table to `Docs/Audits/E2ETestQualityAudit.md` (append below this prompt)

---

## Improvement Plan Output Format

Produce a single Markdown table with these columns:

```markdown
| # | Probe | Score | Domain | Est. Savings | Files Affected | Remediation |
|---|-------|-------|--------|-------------|----------------|-------------|
```

Sort by Score (P0 → P4), then by Est. Savings (high → low).

--- END E2E TEST QUALITY AUDIT TASK ---
```

## Improvement Plan

*(To be filled by the agent after running the probes.)*

| # | Probe | Score | Domain | Est. Savings | Files Affected | Remediation |
|---|-------|-------|--------|-------------|----------------|-------------|
| 1 | Search Grid Navigation | P1 | UI | 45s | [SearchUITests.swift](file:///Users/ryanmcintire/Documents/Trinket/TrinketUITests/Search/SearchUITests.swift) | Use direct launch deep links (`-selectedTab search`) and programmatic text replacement in the search field to filter items quickly rather than scrolling through a large grid. |
| 2 | Tab Navigation Overhead | P1 | UI | 30s | [TabNavigationUITests.swift](file:///Users/ryanmcintire/Documents/Trinket/TrinketUITests/Collection/TabNavigationUITests.swift) | Refactor large test methods to target individual screens using `-launch-screen` deep links, bypassing full tab-to-tab navigation cycles. |
| 3 | Battle Animation Ticks | P2 | UI | 20s | [BattleFlowUITests.swift](file:///Users/ryanmcintire/Documents/Trinket/TrinketUITests/Battle/BattleFlowUITests.swift) | Inject a faster tick-interval override via launch arguments (`-battle-tick-interval 0.05`) to speed up mid-battle UI transition states. |
| 4 | Accessibility Coverage | P2 | UI | N/A | TrinketUITests/Smoke/* | Add `try app.performAccessibilityAudit()` inside core smoke tests. Ensure decorative and visual-only background components are explicitly hidden with `.accessibilityHidden(true)` to avoid test run noise. |
| 5 | Swift Testing Adoption | P3 | Unit | 10s | Packages/*/Tests/* | Introduce Swift Testing incrementally, migrating catalog loop invariant assertions (e.g. `EnemyCatalogTests.swift`) to use `@Test(arguments:)`. |
| 6 | Scroll Hitch Metrics | P3 | Performance | N/A | TrinketUITests/Performance/* | Add targeted performance tests utilizing `XCTHitchMetric` to measure FPS and frame drops when scrolling large collection grids or maps. Consider parsing the Xcode `.xcresult` bundle in CI to automatically generate performance charts. |
| 7 | Multi-Configuration Plans | P3 | UI | N/A | `Smoke.xctestplan`, `FullUI.xctestplan` | Enable multiple configurations (locales, dark/light modes, dynamic type settings) in Xcode test plans to run smoke tests across different visual layouts. |

