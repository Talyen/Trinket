# Unit Test Audit

Goal: Improve unit/package test coverage, quality, and speed — then **fix** the top issues and commit.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append plans, Done tables, or “Last execution” notes to this file.

Standing conventions: `AGENTS.md` § Unit Tests. UI/smoke/exhaustive → [E2ETestQualityAudit.md](E2ETestQualityAudit.md).

## Mission

Run probes, triage, implement up to **Tier-1 and clear Tier-2** fixes (cap sensible blast radius), verify with `./Scripts/test.sh unit`, commit. Summarize the plan in the commit/PR body only.

## Hard stops

- XCTest remains for `TrinketUITests/` only. Unit/package targets use Swift Testing (`import Testing`).
- Do not weaken `BattleStateTestFactory.makeBattle(..., rngSeed: 0)`.
- Do not remove `accessibilityIdentifier`s.
- Do not invent coverage % CI gates unless already configured — report gaps, don’t add policy by surprise.
- Do not expand into UI test rewrites here.

## Baseline reality

Swift Testing migration for unit/package targets is **complete**. New unit tests must use `@Suite` / `@Test` / `#expect` / `#require`. Do not treat “migrate XCTest → Testing” as open epic work.

## Probes

```bash
# Inventory
for d in TrinketTests Packages/*/Tests; do
  count=$(find "$d" -name '*.swift' ! -path '*/Support/*' ! -name '*TestSupport*' ! -name '*Factory*' 2>/dev/null | wc -l)
  echo "$d: $count test files"
done

# Legacy / quality smells in unit targets
rg -n 'import XCTest|XCTAssert|XCTUnwrap|override func setUp' --type swift TrinketTests Packages/*/Tests || true
rg -n 'XCTAssertNotNil' --type swift TrinketTests Packages/*/Tests || true
rg -n 'Task\.sleep|usleep|\bsleep\(' --type swift TrinketTests Packages/*/Tests || true
rg -n 'as!|try!' --type swift TrinketTests Packages/*/Tests || true

# Swift Testing presence (expect widespread)
rg -c '@Test' --type swift TrinketTests Packages/*/Tests | sort -t: -k2 -rn | head -30

# MainActor annotation gaps
rg -l 'PlayerSaveStore|AppState|BattleSession' --type swift TrinketTests Packages/*/Tests \
  | while read -r f; do head -40 "$f" | rg -q '@MainActor' || echo "MISSING @MainActor: $f"; done

# Timing
./Scripts/test-timing.sh report --top 30 --by-class || true
```

## Checks

### Coverage / ownership

Use `Docs/Architecture.md` and package test READMEs. Spot-check:

- Every `EffectKind` covered in handler/apply tests
- New `Player*Store` APIs have write-through persistence tests
- Integration files in BattleEngine stay thin (3–6 tests)

Refresh file counts with `find` each run — do not trust stale tables in old commits.

### Quality

- Assert semantics (events, HP deltas, reload-from-disk), not log fingerprints
- No empty tests; no `try?` that hides failures (`#expect(throws:)` / `#require`)
- Prefer shared fixtures: `AppTestContext`, `BattleStateTestFactory`, `CombatantFixtures`, `SaveTestSupport`
- Naming: behavior-focused (`localMutationSchedulesDebouncedUpload`); Swift Testing needs no `test` prefix

### Concurrency in tests

- Types touching stores / app state: `@MainActor` on suite or tests
- No shared `static var` mutable fixtures
- Await Tasks; no multi-second sleeps — inject short intervals

### Speed

- Flag unit methods >> 1s (except multi-tick integration)
- Budget: keep full `./Scripts/test.sh unit` CI-friendly; use `test-timing.sh assert-budget` when configured

## Fix priority

**Tier 1 (do now):** leftover XCTest asserts in unit targets, `Task.sleep`, empty/commented tests, missing `@MainActor`, silent `try?`.

**Tier 2:** split oversized suites, extract duplicated setup, fill clear module gaps (e.g. missing store roundtrip).

**Tier 3 (only if quick):** tags / `withKnownIssue` / parameterization cleanups.

## Verification

```sh
./Scripts/lint.sh
./Scripts/check-module-boundaries.sh
./Scripts/test.sh unit
./Scripts/test-timing.sh report --last 1 || true
```

## Commit

```
test(<scope>): <imperative improvement>

- <probe-driven fix>
- ./Scripts/test.sh unit

User-Facing: no
```
