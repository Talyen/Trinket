# UI Test Reliability & Signal Audit

Goal: Improve confirmed UI-test reliability, signal, and tier fit without weakening product coverage.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append improvement plans or Done tables to this file.

Unit/package tests → [UnitTestAudit.md](UnitTestAudit.md).  
Interaction / a11y product bugs → [UIInteractionFeedbackAudit.md](UIInteractionFeedbackAudit.md).  
Conventions → `Docs/Platform/Testing.md` + `TrinketUITests/README.md`.

## Mission

Run UI-focused probes, confirm P0–P2 candidates with a focused current run, then make a bounded set of fixes. A clean pass is valid. Put evidence and any skipped candidates in the commit/PR body only.

## Hard stops

- XCTest stays for `TrinketUITests/` (`XCUIApplication`). Do not migrate UI tests to Swift Testing.
- Do not remove `accessibilityIdentifier` values used by UI tests.
- Do not weaken battle determinism.
- Do not change `project.yml` schemes/test plans unless required for a fix you are implementing.
- Do not expand into unit XCTest→Testing migration (see UnitTestAudit + `./Scripts/check-swift-testing-migration.sh`).
- Mid-battle interaction tests: enter via Play map — not `-launch-screen battle` with extreme tick intervals (per `TrinketUITests/README.md`).
- Do not invent wall-clock budgets that conflict with `Docs/Platform/Testing.md` / `AGENTS.md` (smoke is a short UI-only plan).

## Probes

### Speed

```bash
./Scripts/test-timing.sh report --top 30 --by-class || true

rg -n 'Task\.sleep|sleep\(' --type swift TrinketUITests || true
rg -n 'waitForExistence\(timeout:\s*[3-9]' --type swift TrinketUITests || true
rg -n 'assertExistsAfterScroll' --type swift TrinketUITests || true
rg -n 'openHeroesCategory|openPetsCategory|openStage' --type swift TrinketUITests || true
```

Timing history is a lead, not proof: confirm a slow or flaky class with a focused current run before changing it.

### Assertion / quality

```bash
rg -n 'XCTAssertTrue.*\.exists|XCTAssertTrue.*\.isHittable' --type swift TrinketUITests || true
rg -n 'XCTAssertNotNil' --type swift TrinketUITests || true
rg -n '//\s*func test' --type swift TrinketUITests || true
```

### Launch args & page objects

```bash
rg -n 'reset-state|seed-test-progress|disable-cloud-sync|launch-screen|selectedTab' --type swift \
  TrinketUITests Trinket/ || true
rg -n 'accessibilityIdentifier' --type swift TrinketUITests/Support Trinket/ | head -80
ls TrinketUITests/Support/Screens/
```

Default smoke args should remain `-reset-state`, `-seed-test-progress`, `-disable-cloud-sync` unless testing persistence. Prefer page objects (`PlayScreen`, `TabBar`, …) over raw identifier strings scattered in tests.

### Smoke vs exhaustive weight

```bash
for f in TrinketUITests/Smoke/*.swift; do
  echo "$f: $(rg -c 'func test' "$f" || echo 0) tests"
done
rg -c 'func test' --type swift TrinketUITests -g '!*Smoke*' || true
```

### Isolation / shared state

```bash
rg -n 'UserDefaults\.standard' --type swift TrinketUITests || true
rg -n 'continueAfterFailure' --type swift TrinketUITests || true
```

UI tests run **serially** on a single simulator by default — do not assume parallel UI execution when “fixing” flakes.

## Tier rules

| Tier | Command | Belongs here |
|------|---------|--------------|
| Smoke | `./Scripts/test.sh smoke` | One theme per method; load + critical control exists; ~minutes not journeys |
| Exhaustive UI | `./Scripts/test.sh ui` | Multi-step journeys |
| Unit | `./Scripts/test.sh unit` | Rules/state — not full-app spins |

Prefer `-launch-screen` / `-selectedTab` / `-completed-stages` / `-map-scroll-target` over tab+grid navigation. Prefer `replaceText` over long grid scrolls.

## Scoring

| Score | Criteria |
|-------|----------|
| P0 | Flaky CI failure, crash in test harness |
| P1 | Clear multi-second savings or flaky class fix |
| P2 | Tier misplacement / duplicate coverage with real cost |
| P3 | Consistency (helpers, naming) |
| P4 | Nice-to-have (extra metrics, multi-config) — skip unless trivial |

## Fixes (allowed)

- Shorten excessive `waitForExistence` after deep-link launch
- Move multi-step assertions from smoke → exhaustive
- Replace scroll hunts with launch args
- Use page objects / `assertExists` consistently
- Align tests with default launch-arg helpers in `TrinketUITestCase`

Do **not** add `performAccessibilityAudit()` in this audit unless a screen is already known-stable in CI; product a11y gaps belong in [UIInteractionFeedbackAudit.md](UIInteractionFeedbackAudit.md).

## Verification

```sh
./Scripts/lint.sh
./Scripts/check-module-boundaries.sh
./Scripts/test.sh smoke
# If exhaustive class touched:
./Scripts/test.sh ui <ClassName>
```

Confirm: no identifier removals; no battle RNG changes; recommendations match `Docs/Platform/Testing.md` / `TrinketUITests/README.md`. Skip smoke/UI when the simulator toolchain is absent; note skips in the commit body.

## Commit

```
test(ui): <imperative speed or quality fix>

- <probe-driven change>
- smoke / targeted ui verification

User-Facing: no
```
