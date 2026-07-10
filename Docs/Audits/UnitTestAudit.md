# Unit Test Value Audit

Goal: Improve the regression value, correctness, and speed of unit/package tests.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append plans, Done tables, or “Last execution” notes to this file.

Standing conventions: `Docs/Platform/Testing.md`. UI/smoke/exhaustive → [E2ETestQualityAudit.md](E2ETestQualityAudit.md).
Battle test ownership: `Packages/BattleEngine/Tests/README.md`.

## Mission

Run probes, then make a bounded set of Tier-1 or clear Tier-2 improvements with demonstrated regression value. A clean pass is valid. Summarize evidence in the commit/PR body only.

## Hard stops

- XCTest remains for `TrinketUITests/` only. Unit/package targets use Swift Testing (`import Testing`).
- Do not weaken `BattleStateTestFactory.makeBattle(..., rngSeed: 0)`.
- Do not remove `accessibilityIdentifier`s.
- Do not invent coverage % CI gates unless already configured — report gaps, don’t add policy by surprise.
- Do not expand into UI test rewrites here.
- Do not treat “migrate XCTest → Testing” as open epic work — enforce via the ratchet script below.

## Probes

```bash
# CI ratchet — unit targets must not import XCTest
./Scripts/check-swift-testing-migration.sh

# Inventory
for d in TrinketTests Packages/*/Tests; do
  count=$(find "$d" -name '*.swift' ! -path '*/Support/*' ! -name '*TestSupport*' ! -name '*Factory*' 2>/dev/null | wc -l)
  echo "$d: $count test files"
done

# Legacy / quality smells in unit targets (should be empty / rare)
rg -n 'import XCTest|XCTAssert|XCTUnwrap|override func setUp' --type swift TrinketTests Packages/*/Tests || true
rg -n 'XCTAssertNotNil' --type swift TrinketTests Packages/*/Tests || true
rg -n 'Task\.sleep|usleep|\bsleep\(' --type swift TrinketTests Packages/*/Tests || true
rg -n 'as!|try!' --type swift TrinketTests Packages/*/Tests || true

# Swift Testing presence (expect widespread)
rg -c '@Test' --type swift TrinketTests Packages/*/Tests | sort -t: -k2 -rn | head -30

# Timing
./Scripts/test-timing.sh report --top 30 --by-class || true
```

## Checks

### Coverage / ownership

Use `Docs/Platform/Architecture.md` and package test READMEs (especially BattleEngine Tests README). Spot-check:

- Every `EffectKind` covered in handler/apply tests
- New `Player*Store` APIs have write-through persistence tests
- Integration files in BattleEngine stay thin (3–6 tests)

Refresh file counts with `find` each run — do not trust stale tables in old commits, and do not select work merely because a module has fewer files.

### Shared fixtures (prefer these over duplicating)

| Helper | Location |
|--------|----------|
| `AppTestContext` / `AppTestSupport` | `TrinketTests/Support/` |
| `PersistenceTestContext` | `TrinketPersistenceTests/Support/` |
| `SaveTestSupport`, `CombatantFixtures`, battle parties | `Packages/TrinketTestSupport/` |
| `BattleStateTestFactory`, `BattleTestFixtures` | `Packages/BattleEngine/Tests/` |

### Quality

- Assert semantics (events, HP deltas, reload-from-disk), not log fingerprints
- No empty tests; no `try?` that hides failures (`#expect(throws:)` / `#require`)
- Naming: behavior-focused; Swift Testing needs no `test` prefix

### Concurrency in tests

- Add `@MainActor` only where the tested API or compiler isolation diagnostics require it
- No shared `static var` mutable fixtures
- Await Tasks; replace multi-second production-delay sleeps with injected intervals and polling

### Speed

- Treat historical timing output as a lead; confirm a hotspot in a focused current run
- Flag unit methods >> 1s (except multi-tick integration)
- Budget: keep full `./Scripts/test.sh unit` CI-friendly; use `test-timing.sh assert-budget` when configured

## Fix priority

**Tier 1:** ratchet failures from `check-swift-testing-migration.sh`, leftover XCTest asserts in unit targets, empty/commented tests, silent `try?`, and demonstrated actor-isolation errors or multi-second waits.

**Tier 2:** split oversized suites, extract duplicated setup, fill clear module gaps (e.g. missing store roundtrip).

**Tier 3 (only if quick):** tags / `withKnownIssue` / parameterization cleanups.

## Verification

```sh
./Scripts/check-swift-testing-migration.sh
./Scripts/lint.sh
./Scripts/check-module-boundaries.sh
./Scripts/test.sh unit   # toolchain permitting
./Scripts/test-timing.sh report --last 1 || true
```

## Commit

```
test(<scope>): <imperative improvement>

- <probe-driven fix>
- ./Scripts/test.sh unit

User-Facing: no
```
