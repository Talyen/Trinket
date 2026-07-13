# UI Test Reliability & Signal Audit

**Goal:** Improve confirmed UI-test reliability, signal, and tier fit without weakening product coverage.

**Siblings:** unit/package → [UnitTestAudit.md](UnitTestAudit.md); product interaction/a11y → [UIInteractionFeedbackAudit.md](UIInteractionFeedbackAudit.md). Conventions: `Docs/Platform/Testing.md` + `TrinketUITests/README.md`.

## Intent

Confirm P0–P2 UI-test candidates with a focused current run, then make a bounded set of fixes. A clean pass is valid.

## Hard stops

- XCTest stays for `TrinketUITests/` (`XCUIApplication`). Do not migrate UI tests to Swift Testing.
- Do not remove `accessibilityIdentifier` values used by UI tests.
- Do not weaken battle determinism.
- Mid-battle interaction tests: enter via Play map — not `-launch-screen battle` with extreme tick intervals.
- Do not invent wall-clock budgets that conflict with Testing.md / `AGENTS.md` (smoke is a short UI-only plan).
- Do not expand into unit XCTest→Testing migration (UnitTestAudit + `check-swift-testing-migration.sh`).

## Tier rules

| Tier | Command | Belongs here |
|------|---------|--------------|
| Smoke | `./Scripts/test.sh smoke` | One theme per method; load + critical control exists; ~minutes not journeys |
| Exhaustive UI | `./Scripts/test.sh ui` | Multi-step journeys |
| Unit | `./Scripts/test.sh unit` | Rules/state — not full-app spins |

Prefer `-launch-screen` / `-selectedTab` / `-completed-stages` / `-map-scroll-target` over tab+grid navigation. Prefer `replaceText` over long grid scrolls. Default smoke args: `-reset-state`, `-seed-test-progress`, `-disable-cloud-sync` unless testing persistence.

## Scoring

| Score | Criteria |
|-------|----------|
| P0 | Flaky CI failure, crash in test harness |
| P1 | Clear multi-second savings or flaky class fix |
| P2 | Tier misplacement / duplicate coverage with real cost |
| P3 | Consistency (helpers, naming) |
| P4 | Nice-to-have — skip unless trivial |

## Domain rules

UI tests run **serially** on a single simulator — do not assume parallel UI execution when “fixing” flakes. Prefer page objects (`PlayScreen`, `TabBar`, …) over raw identifier strings. Do not add accessibility audits; product accessibility scope is defined by PD-007 and UIInteractionFeedbackAudit.

**Allowed fixes:** shorten excessive waits after deep-link launch; move multi-step assertions from smoke → exhaustive; replace scroll hunts with launch args; use page objects / `assertExists` consistently.

## Probe hints

`Task.sleep` / long `waitForExistence`; scroll-hunt helpers; existence-only asserts; launch-arg coverage; smoke vs exhaustive test weight; `UserDefaults.standard` / `continueAfterFailure` isolation smells. Timing history (`test-timing.sh`) is a lead, not proof.

## Verify

`lint.sh` + boundaries; `test.sh smoke`; targeted `test.sh ui <ClassName>` if an exhaustive class was touched. Skip smoke/UI when the simulator is absent; note skips.
