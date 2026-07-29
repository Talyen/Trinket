# Unit Test Portfolio Audit

**Goal:** Reduce unit/package test LOC, declarations, expanded cases, and runtime while preserving unique high-value semantic owners.

Conventions: `Docs/Platform/Testing.md`. Battle ownership: `Packages/BattleEngine/Tests/README.md`.

## Intent

Confirm duplicate, weaker, implementation-detail, slow, or over-expanded cases with a stronger owner elsewhere. A clean pass is valid; do not add coverage to manufacture value. Planning and phasing: [README.md](README.md).

## Hard stops

- XCTest remains for `TrinketUITests/` only. Unit/package targets use Swift Testing (`import Testing`).
- Do not invent coverage % CI gates unless already configured.
- Do not treat “migrate XCTest → Testing” as open epic work — enforce via `./Scripts/check-swift-testing-migration.sh`.
- Do not optimize declaration count alone: `@Test(arguments:)` may hide more executed cases and runtime.
- Preserve unique battle, persistence, balance, app-transition, and player-flow owners. Do not delete a failing journey merely to reduce the portfolio.

## Fix priority

Shared scale: [README.md](README.md).

**P1:** same assertion owned twice; weaker app-shell echoes of package owners; exact catalog counts, pixel tables, plain-struct round trips, empty/commented tests, hidden `try?`, or multi-second waits. Also fixture/support harnesses whose LOC dwarfs unique semantic assertions; presentation, layout-constant, glyph, or plumbing cases that [Testing.md](../Platform/Testing.md) already bans; `@Test(arguments:)` (or sibling case fans) whose expanded executions dominate runtime without a distinct invariant per case.

**P2:** merge sibling cases only when it reduces executed work or setup cost; reuse an existing fixture; inject short intervals; move an assertion to its cheaper semantic owner and delete the weaker copy; trim support helpers that exist only to feed deleted or merged cases.

**P3 (only if quick):** drop redundant assertions inside a kept test; tags or `withKnownIssue` cleanup with demonstrated value.

## Domain rules

**Shared fixtures (prefer over duplicating):**

| Helper | Location |
|--------|----------|
| `AppTestContext` / `AppTestSupport` | `Packages/TrinketAppState/Tests/TrinketAppStateTests/Support/` |
| `PersistenceTestContext` | `TrinketPersistenceTests/Support/` |
| `CombatantFixtures`, battle parties | `Packages/TrinketTestSupport/` |
| `SaveTestSupport` | PersistenceTests + TrinketAppStateTests support (not TrinketTestSupport) |
| `BattleStateTestFactory`, `BattleTestFixtures` | `Packages/BattleEngine/Tests/` |

**Quality:** assert semantics (events, HP deltas, reload-from-disk), not log fingerprints; no empty tests; no `try?` that hides failures (`#expect(throws:)` / `#require`).

**Concurrency:** `@MainActor` only where the API or compiler requires it; no shared `static var` mutable fixtures; await Tasks; replace multi-second production-delay sleeps with injected intervals and polling.

**Coverage ownership:** Battle rules live in package matrices; persistence in store/sanitizer journeys; catalogs in invariants rather than exact snapshots; app tests only own orchestration packages cannot express. Do not select work because a module has fewer files.

**Fixture / support sprawl:** Prefer shared owners in the table above over package-local copies. A support file or test class that is primarily harness mass (setup, golden tables, presentation matrices) with few unique semantic assertions is a P1 candidate — shrink or delete the harness, do not add more fixtures to “organize” it. Route live production mass without a test-portfolio angle to AuthoredMassGrowthAudit.

Track authored declarations and expanded executions separately. Inventory hotspots by both metrics: a merge or deletion is successful only when it reduces duplication, expanded executions, runtime/setup, or maintenance surface—not merely the number of `@Test` attributes. Report the before/after direction in the handoff: authored declarations, expanded executions, or suite runtime.
