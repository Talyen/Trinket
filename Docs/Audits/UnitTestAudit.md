# Unit Test Portfolio Audit

**Goal:** Maximize unit/package semantic signal per maintenance and runtime cost: remove weak/redundant surface, repair misleading tests, and fill confirmed consequential ownership gaps.

Conventions: `Docs/Platform/Testing.md`. Battle ownership: `Packages/BattleEngine/Tests/README.md`.

## Intent

Confirm duplicate, weaker, implementation-detail, slow, over-expanded, flaky, or falsely reassuring cases, plus consequential invariants that have no semantic owner. Prefer reshaping the complete behavior family in its cheapest owner. A clean pass is valid; do not add coverage to manufacture value, but a justified fix may grow slightly when new owner-level coverage replaces weak evidence or protects a distinct high-impact invariant. Planning and phasing: [README.md](README.md).

## Hard stops

- XCTest remains for `TrinketUITests/` only. Unit/package targets use Swift Testing (`import Testing`).
- Do not invent coverage % CI gates unless already configured.
- Do not treat “migrate XCTest → Testing” as open epic work — enforce via `./Scripts/check-swift-testing-migration.sh`.
- Do not optimize declaration count alone: `@Test(arguments:)` may hide more executed cases and runtime.
- Preserve unique battle, persistence, balance, app-transition, and player-flow owners. Do not delete a failing journey merely to reduce the portfolio.

## Fix priority

Shared scale: [README.md](README.md).

**P1:** same assertion owned twice; weaker app-shell echoes of package owners; exact catalog counts, pixel tables, plain-struct round trips, empty/commented tests, hidden `try?`, multi-second waits, flaky/nondeterministic setup, or a test that passes without exercising its claimed behavior. Also fixture/support harnesses whose LOC dwarfs unique semantic assertions; presentation, layout-constant, glyph, or plumbing cases that [Testing.md](../Platform/Testing.md) already bans; `@Test(arguments:)` (or sibling case fans) whose expanded executions dominate runtime without a distinct invariant per case. A missing invariant is P1 only when failure would be consequential, no existing owner covers it, and the test-addition gate is satisfied.

**P2:** merge sibling cases only when it reduces executed work or setup cost; reuse an existing fixture; inject short intervals; move an assertion to its cheaper semantic owner and delete the weaker copy; trim support helpers that exist only to feed deleted or merged cases; add or strengthen the cheapest owner-level case for a confirmed consequential gap, removing misleading weaker coverage when present.

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

Track authored declarations and expanded executions separately. Inventory hotspots by both metrics and evaluate signal ownership: a change is successful when it reduces duplication/runtime/setup/maintenance, corrects false evidence, or gives a consequential invariant one cheaper semantic owner. Do not judge solely by `@Test` count or net LOC. Report the before/after direction in the handoff: semantic owners, authored declarations, expanded executions, suite runtime, or flaky/false-positive class removed.
