# Unit Test Portfolio Audit

**Goal:** Reduce unit/package test LOC, declarations, expanded cases, and runtime while preserving unique high-value semantic owners.

Conventions: `Docs/Platform/Testing.md`. Battle ownership: `Packages/BattleEngine/Tests/README.md`.

## Intent

Confirm duplicate, weaker, implementation-detail, slow, or over-expanded cases with a stronger owner elsewhere. Write a plan to fix all identified test portfolio issues (breaking into phases if the scope is large). A clean pass is valid; do not add coverage to manufacture value.

## Hard stops

- XCTest remains for `TrinketUITests/` only. Unit/package targets use Swift Testing (`import Testing`).
- Do not invent coverage % CI gates unless already configured.
- Do not treat “migrate XCTest → Testing” as open epic work — enforce via `./Scripts/check-swift-testing-migration.sh`.
- Do not optimize declaration count alone: `@Test(arguments:)` may hide more executed cases and runtime.
- Preserve unique battle, persistence, balance, app-transition, and player-flow owners. Do not delete a failing journey merely to reduce the portfolio.

## Fix priority

**Tier 1:** same assertion owned twice; weaker app-shell echoes of package owners; exact catalog counts, pixel tables, plain-struct round trips, empty/commented tests, hidden `try?`, or multi-second waits.

**Tier 2:** merge sibling cases only when it reduces executed work or setup cost; reuse an existing fixture; inject short intervals; move an assertion to its cheaper semantic owner and delete the weaker copy.

**Tier 3 (only if quick):** drop redundant assertions inside a kept test; tags or `withKnownIssue` cleanup with demonstrated value.

## Domain rules

**Shared fixtures (prefer over duplicating):**

| Helper | Location |
|--------|----------|
| `AppTestContext` / `AppTestSupport` | `TrinketTests/Support/` |
| `PersistenceTestContext` | `TrinketPersistenceTests/Support/` |
| `SaveTestSupport`, `CombatantFixtures`, battle parties | `Packages/TrinketTestSupport/` |
| `BattleStateTestFactory`, `BattleTestFixtures` | `Packages/BattleEngine/Tests/` |

**Quality:** assert semantics (events, HP deltas, reload-from-disk), not log fingerprints; no empty tests; no `try?` that hides failures (`#expect(throws:)` / `#require`).

**Concurrency:** `@MainActor` only where the API or compiler requires it; no shared `static var` mutable fixtures; await Tasks; replace multi-second production-delay sleeps with injected intervals and polling.

**Coverage ownership:** Battle rules live in package matrices; persistence in store/sanitizer journeys; catalogs in invariants rather than exact snapshots; app tests only own orchestration packages cannot express. Do not select work because a module has fewer files.

Track authored declarations and expanded executions separately. A merge is successful only when it reduces duplication, runtime/setup, or maintenance surface—not merely the number of `@Test` attributes.

## Probe hints

- **XCTest Import Check:** Run `./Scripts/check-swift-testing-migration.sh` to ensure unit/package targets import `Testing` rather than `XCTest`.
- **Trivial Property & Round-Trip Tests:** Search unit test suites for tests asserting basic struct getters/setters, static member initialization, or plain-struct JSON encoding/decoding without domain logic.
- **Timer Delays & Sleep Invocations:** Search unit test targets for `Task.sleep`, `Thread.sleep`, or `usleep`; replace real wall-clock delays with mock time providers or micro-delay polling.
- **Fragile String Error Assertions:** Search for assertions checking `error.localizedDescription` or error string representations (`#expect("\(error)".contains(...))`); replace string matching with strongly-typed enum error assertions.
- **Duplicate Tier Ownership:** Compare `TrinketTests/` against `Packages/*/Tests/`; verify app-level unit tests do not duplicate lower-level package rule matrix coverage.
- **Catalog Snapshot Counts:** Search for exact static count assertions (`#expect(items.count == 42)`); replace snapshot counts with ID uniqueness and structural invariant assertions.
