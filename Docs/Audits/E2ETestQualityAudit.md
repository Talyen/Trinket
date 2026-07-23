# UI Test Reliability & Signal Audit

**Goal:** Improve confirmed UI-test reliability, signal, and tier fit without weakening product coverage.

Conventions: `Docs/Platform/Testing.md` + `TrinketUITests/README.md`.

## Intent

Confirm P0–P2 candidates across suites and write a plan to address all identified issues (breaking into phases if the scope is large), preferring delete → merge → move to a cheaper tier → shorten. Add page-object or harness surface only when at least three current uses become shorter or one enforced test boundary requires it.

## Hard stops

- XCTest stays for `TrinketUITests/` (`XCUIApplication`). Do not migrate UI tests to Swift Testing.
- Mid-battle interaction tests: enter via Play map — not `-launch-screen battle` with extreme tick intervals.
- Do not invent wall-clock budgets that conflict with Testing.md / `AGENTS.md` (smoke is a short UI-only plan).
- Do not expand into unit XCTest→Testing migration (UnitTestAudit + `check-swift-testing-migration.sh`).

## Tier rules

| Tier | Command | Belongs here |
|------|---------|--------------|
| Smoke | `./Scripts/test.sh smoke` / `smoke-full` | Shell/entry canaries only (see Testing.md rubric); ~minutes not journeys |
| Exhaustive UI | `./Scripts/test.sh ui` | State-changing journeys + one-owner safety invariants |
| Unit | `./Scripts/test.sh unit` | Rules/state — not full-app spins |

Do not re-add layout/chrome, copy catalogs, or smoke+FullUI duplicates. Prefer `-launch-screen` / `-selectedTab` / `-completed-stages` / `-map-scroll-target` over tab+grid navigation. Prefer `replaceText` over long grid scrolls. Default smoke args: `-reset-state`, `-seed-test-progress`, `-disable-cloud-sync` unless testing persistence.

## Scoring

| Score | Criteria |
|-------|----------|
| P0 | Flaky CI failure, crash in test harness |
| P1 | Clear multi-second savings or flaky class fix |
| P2 | Tier misplacement / duplicate coverage with real cost |
| P3 | Consistency (helpers, naming) |
| P4 | Nice-to-have — skip unless trivial |

## Domain rules

UI tests run **serially** on one simulator. Reuse existing page objects; do not extract a new one for one or two call sites. Do not add accessibility audits; product accessibility scope is defined by PD-007 and UIInteractionFeedbackAudit.

**Allowed fixes:** delete duplicate journeys/assertions; shorten excessive waits after deep-link launch; move multi-step assertions from smoke → exhaustive without retaining the smoke copy; replace scroll hunts with launch args; reuse page objects / `assertExists` consistently.

## Probe hints

- **Hardcoded Wall-Clock Delays:** Search `TrinketUITests/` for `Thread.sleep`, `usleep`, `sleep(`, `Task.sleep`, or `XCTWaiter.wait` calls; replace arbitrary sleep delays with predicate expectations or `waitForExistence`.
- **Brittle Index Element Queries:** Search for `.element(boundBy: [0-9]+)` or `.children(matching: .any).element(boundBy:)` in `TrinketUITests/Support/Screens/`; replace fragile index lookups with explicit `AccessibilityID` queries.
- **Missing Accessibility Identifiers:** Search UI views in `Trinket/Features/` for interactive controls (`Button`, `Toggle`, `Slider`) that lack `.accessibilityIdentifier(...)`, forcing UI tests to rely on localized text matching.
- **Excessive Timeout Margins:** Search for `waitForExistence(timeout: [0-9]+)` exceeding `defaultTimeout` (3s); shorten unnecessary 10s+ wait margins after deep-link launches.
- **Smoke vs Exhaustive Duplication:** Compare `TrinketUITests/Smoke/` tests against `TrinketUITests/` journey suites; verify smoke tests only contain lightweight entry checks without repeating multi-step journey assertions.
