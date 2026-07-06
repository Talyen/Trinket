# Test Quality Audit

Goal: Tests protect behavior without adding maintenance burden — following the conventions in `AGENTS.md`.

## Targets

- `./Scripts/test.sh unit` — all unit tests pass (app + all package schemes in parallel)
- `./Scripts/test.sh smoke` — UI smoke tests pass (~2 min)
- Full test suite should complete without warnings about orphaned test files or disabled tests

## Checks

### Assert outcomes, not implementation

- Battle tests: assert *semantics* (status kinds, milestones, victory/defeat, health deltas) rather than full log fingerprints
- Use `BattleEvent` predicates from `BattleTestFixtures` — do not assert on log formatting strings
- For store tests: mutate → reload from disk → assert — don't assert on internal cache state or private properties

### No trivial assertions

- No `XCTAssertNotNil(foo)` where `foo` must exist by construction (use `XCTUnwrap` or `guard let`)
- No "function exists" or "returns defined" tests — every assertion must protect a behavioral contract
- No empty test methods or test methods that only call `super.setUp()`
- UI tests: use `assertExists` with `accessibilityIdentifier` — do not assert on existence of the app itself or generic containers

### Duplicate setup — extract shared fixtures

- Test files within the same domain should share via `TrinketTests/Support/` helpers:
  - `AppTestSupport.makeAppState(...)` for app-state tests
  - `BattleStateTestFactory.makeBattle(...)` for battle rules (always use seed 0)
  - `CombatantFixtures` for handler/model tests
  - `SaveTestSupport.makeTempDirectory()` for persistence tests
  - `BattleTestFixtures.standardParty` for integration tick exercises
- If a test file duplicates `setUp` logic already present in a sibling, extract to a shared helper or base class
- Do not duplicate catalog loop tests across files — content invariant tests live in `TrinketContentTests`

### Orphaned or copy-pasted test files

- Every test file should map to a production source file or module
- Remove test files for deleted or renamed production code
- No commented-out test methods — delete or uncomment
- No test files that only contain `import XCTest` with no test methods
- `./Scripts/test.sh unit --no-build` will warn on stale references — take those warnings seriously

### No dev-only QA shortcuts in UI tests

- UI tests must not use debug gestures, hidden buttons, or developer-only QA toggles
- Prefer `-launch-screen` / `-selectedTab` / `-completed-stages` launch args for setup — not hidden menu items or swipe sequences
- Mid-battle tests should enter via Play map navigation, not `-launch-screen battle` with extreme tick intervals
- `-reset-state` is the default; use persistence-testing args (`-completed-stages`, `-launch-screen`) only when the test specifically validates saved state

### Definition of Done alignment

Each feature change should satisfy the DoD from `AGENTS.md`:

1. Rules/models → at least one focused unit test in the owning package
2. New `Player*Store` API → write-through persistence test in `TrinketPersistenceTests`
3. New catalog content → invariant test in the matching `*CatalogTests` class
4. New `EffectKind` → registry parity test + `EffectHandlersApplyTests`
5. New app orchestration on `AppState` / `BattleSession` → focused `TrinketTests` test
6. New user flow → `accessibilityIdentifier` + one smoke UI test
7. `./Scripts/test.sh unit` (full, unfiltered) before commit when package code changed

### Speed hygiene

- Prefer `-launch-screen` deep links over tab + grid navigation in UI tests
- Avoid `assertExistsAfterScroll` for far-off Play map nodes — use `-completed-stages` or `-map-scroll-target`
- Use inventory/search field filtering (`replaceText`) instead of long grid scroll loops
- Inject short intervals in production init params for async/debounce tests — never `Task.sleep` for multi-second production delays
- Check hotspots: `./Scripts/test-timing.sh report --top 30`
