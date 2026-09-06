# 17. Unit Test Portfolio Audit

**Goal:** Improve the unit/package portfolio's trustworthy coverage of consequential
behavior while reducing avoidable runtime, redundancy, and fixture maintenance.

Use the [shared audit contract](README.md) for scope, evidence, severity, and sizing.
[Testing](../Platform/Testing.md) owns framework choice, fixtures, coverage decisions,
and semantic test placement. Package tests use Swift Testing; XCTest belongs to UI
tests, with violations handled by the existing API gate.

## What to investigate

Tests that pass without exercising their claimed behavior, swallowed failures,
nondeterministic/shared state, duplicated assertions of the same contract,
expensive setup or waits, and consequential invariants with no effective owner.
Compare what tests prove, including setup and failure modes, not merely their names
or similar assertions. A smaller portfolio is not inherently a better one.

## Evidence and remedy

For removal/merging, identify the surviving owner and show it covers the same
consequential behavior under the relevant conditions. For missing coverage, apply
Testing.md's coverage decision and strengthen the cheapest existing semantic owner.
A lack of test files or a low case count is not evidence of a gap.

Correct false evidence before optimizing its runtime. Assert semantic outcomes;
persistence coverage must establish durability rather than an in-memory setter
round trip. Replace unnecessary production-delay waits through existing test seams,
and isolate shared setup where its lifetime causes interference. Reuse the canonical
fixtures instead of building another support layer to organize redundant tests.

Track expanded executions separately from declarations. Parameterized cases may
prove distinct behavior or may repeat the same work; neither form establishes value
by itself. Report the relevant improvement: trustworthy invariant coverage, reduced
setup/executed work, clearer ownership, or repaired nondeterminism.

## Boundaries

- Preserve distinct battle, persistence, balance, transition, and player-flow coverage.
  Do not delete failures or relax assertions to make the suite green.
- Apply Testing.md's exclusions for presentation/plumbing tests; do not reproduce
  a parallel list of banned test shapes here.
- Do not force shared fixtures across package boundaries or introduce production
  testability APIs without a consequential gap and a justified owner.
- UI portfolio quality belongs to [10](10_E2ETestQualityAudit.md); production-only
  maintenance cost belongs to [02](02_MaintenanceSurfaceLocalityAudit.md).
