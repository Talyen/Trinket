# UI Test Reliability & Signal Audit

**Goal:** Improve confirmed UI-test reliability, signal, tier fit, and application testability without weakening product coverage.

Conventions: `Docs/Platform/Testing.md` + `TrinketUITests/README.md`.

## Intent

Confirm P0–P2 reliability, signal, tier-fit, isolation, and testability issues across UI tests, launch/reset seams, authored harnesses, and CI routing. Prefer delete → merge → move to a cheaper tier → shorten. Add page-object or harness surface only when at least three current uses become shorter or one enforced test boundary requires it. A minimal production seam may ship when it establishes that boundary and does not expose test-only behavior to players. Planning and phasing: [README.md](README.md).

## Hard stops

- XCTest stays for `TrinketUITests/` (`XCUIApplication`). Do not migrate UI tests to Swift Testing.
- Mid-battle interaction tests: enter via Play map — not `-launch-screen battle` with extreme tick intervals.
- Do not invent wall-clock budgets that conflict with Testing.md / `AGENTS.md` (smoke is a short UI-only plan).
- Do not expand into unit XCTest→Testing migration (UnitTestAudit + `check-swift-testing-migration.sh`).

## Tier rules

| Tier | Belongs here |
|------|--------------|
| Smoke | Shell/entry canaries only (see Testing.md rubric); short UI-only plan, not journeys |
| Exhaustive UI | State-changing journeys + one-owner safety invariants |
| Unit | Rules/state — not full-app spins |

Do not re-add layout/chrome, copy catalogs, or smoke+FullUI duplicates. Prefer the cheapest stable entry path per Testing.md (deep-link / launch args over brittle navigation).

## Scoring

Shared scale: [README.md](README.md).

| Score | Criteria |
|-------|----------|
| P0 | Flaky CI failure, crash in test harness |
| P1 | Clear multi-second savings or flaky class fix |
| P2 | Tier misplacement / duplicate coverage with real cost |
| P3 | Consistency (helpers, naming), nice-to-haves — skip unless trivial |

## Domain rules

UI tests run **serially** on one simulator. Reuse existing page objects; do not extract a new one for one or two call sites. Deterministic launch state, reset/isolation behavior, stable entry routes, identifiers required by owned journeys, and harness/CI state leakage are in scope. Do not add accessibility audits; product accessibility scope is defined by PD-007 and UIInteractionFeedbackAudit.

E2E owns an identifier change only when it is required to stabilize an existing owned journey; UIInteractionFeedback owns the broader shipping-control inventory and visible/native interaction behavior.

Successful fixes preserve unique journey coverage while improving reliability, isolation, testability, or tier fit: delete duplicate journeys/assertions; shorten excessive waits after stable entry; move multi-step assertions from smoke → exhaustive without retaining the smoke copy; use stable accessibility queries over brittle indexes; consolidate an entire confirmed journey family across tiers; repair deterministic launch/reset or CI routing when it causes the same reliability problem. Report the before/after direction in the handoff: suite runtime, journey count, flaky class, state leakage, or unstable entry removed.

## Example signals

Hardcoded sleeps, index-bound element queries, missing journey-owned accessibility identifiers, excessive wait timeouts after deep-link launch, smoke suites repeating exhaustive journey assertions, nondeterministic launch/reset state, cross-test leakage, duplicated navigation setup, and CI configuration that runs the wrong UI tier.
