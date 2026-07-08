# E2E / UI Test Quality & Speed Audit

Goal: Improve UI smoke and exhaustive tests — speed, tier fit, duplication, assertion quality — then **fix** the top issues and commit.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append improvement plans or Done tables to this file.

Unit/package tests → [UnitTestAudit.md](UnitTestAudit.md). Conventions → `AGENTS.md` § UI Tests.

## Mission

Run UI-focused probes, triage P0–P2, implement up to **5** fixes (deep links, timeout slimming, smoke/exhaustive split, flaky waits), verify with smoke (and targeted UI if needed), commit. Put the scored plan in the commit/PR body only.

## Hard stops

- XCTest stays for `TrinketUITests/` (`XCUIApplication`). Do not migrate UI tests to Swift Testing.
- Do not remove `accessibilityIdentifier` values used by UI tests.
- Do not weaken battle determinism.
- Do not change `project.yml` schemes/test plans unless required for a fix you are implementing.
- Do not expand into unit XCTest→Testing migration (already done; see UnitTestAudit).
- Mid-battle interaction tests: enter via Play map — not `-launch-screen battle` with extreme tick intervals (per `AGENTS.md`).

## Probes

### Speed

```bash
./Scripts/test-timing.sh report --top 30 --by-class || true

rg -n 'Task\.sleep|sleep\(' --type swift TrinketUITests || true
rg -n 'waitForExistence\(timeout:\s*[3-9]' --type swift TrinketUITests || true
rg -n 'assertExistsAfterScroll' --type swift TrinketUITests || true
rg -n 'openHeroesCategory|openPetsCategory|openStage' --type swift TrinketUITests || true
```

### Assertion / quality

```bash
rg -n 'XCTAssertTrue.*\.exists|XCTAssertTrue.*\.isHittable' --type swift TrinketUITests || true
rg -n 'XCTAssertNotNil' --type swift TrinketUITests || true
rg -n '//\s*func test' --type swift TrinketUITests || true
```

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

## Tier rules

| Tier | Command | Belongs here |
|------|---------|--------------|
| Smoke | `./Scripts/test.sh smoke` | One theme per method; load + critical control exists; ~minutes not journeys |
| Exhaustive UI | `./Scripts/test.sh ui` | Multi-step journeys |
| Unit | `./Scripts/test.sh unit` | Rules/state — not full-app spins |

Prefer `-launch-screen` / `-selectedTab` / `-completed-stages` / `-map-scroll-target` over tab+grid navigation. Prefer `replaceText` over long grid scrolls.

Reconcile timing expectations with `AGENTS.md` (smoke is a short UI-only plan). Do not invent conflicting wall-clock budgets in this file.

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
- Optional: `performAccessibilityAudit()` on a primary tab — only if stable

## Verification

```sh
./Scripts/lint.sh
./Scripts/check-module-boundaries.sh
./Scripts/test.sh smoke
# If exhaustive class touched:
./Scripts/test.sh ui <ClassName>
```

Confirm: no identifier removals; no battle RNG changes; recommendations match `AGENTS.md` UI guidance.

## Commit

```
test(ui): <imperative speed or quality fix>

- <probe-driven change>
- smoke / targeted ui verification

User-Facing: no
```
