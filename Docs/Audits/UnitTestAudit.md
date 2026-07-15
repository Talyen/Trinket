# Unit Test Value Audit

**Goal:** Improve the regression value, correctness, and speed of unit/package tests.

**Siblings:** UI/smoke/exhaustive → [E2ETestQualityAudit.md](E2ETestQualityAudit.md). Conventions: `Docs/Platform/Testing.md`. Battle ownership: `Packages/BattleEngine/Tests/README.md`.

## Intent

Make a bounded set of Tier-1 or clear Tier-2 improvements with demonstrated regression value. A clean pass is valid. If several weak tests share duplicated setup or an oversized suite, prefer that structural Tier-2 remedy — and propose when significant per [README.md](README.md).

## Hard stops

- XCTest remains for `TrinketUITests/` only. Unit/package targets use Swift Testing (`import Testing`).
- Do not weaken `BattleStateTestFactory.makeBattle(..., rngSeed: 0)`.
- Do not remove `accessibilityIdentifier`s.
- Do not invent coverage % CI gates unless already configured.
- Do not treat “migrate XCTest → Testing” as open epic work — enforce via `./Scripts/check-swift-testing-migration.sh`.

## Fix priority

**Tier 1:** ratchet failures, leftover XCTest asserts in unit targets, empty/commented tests, silent `try?`, demonstrated actor-isolation errors or multi-second waits.

**Tier 2:** split oversized suites, extract duplicated setup, fill clear module gaps (e.g. missing store roundtrip).

**Tier 3 (only if quick):** tags / `withKnownIssue` / parameterization cleanups.

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

**Coverage ownership:** spot-check via Architecture.md and package test READMEs (every `EffectKind`, new store write-through, thin BattleEngine integration files). Do not select work merely because a module has fewer files.

## Probe hints

`check-swift-testing-migration.sh`; leftover `import XCTest` / `XCTAssert*` in unit targets; `Task.sleep` / `as!` / `try!` in tests; `test-timing.sh` hotspots (confirm with a focused current run).

## Verify

`check-swift-testing-migration.sh`, `lint.sh`, boundaries, focused `test.sh unit` (toolchain permitting).
