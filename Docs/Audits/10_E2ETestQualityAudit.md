# 10. UI Test Reliability & Signal Audit

**Goal:** Make UI tests provide trustworthy evidence of shipping outcomes with
appropriate isolation, tier placement, and execution cost.

Use the [shared audit contract](README.md) for scope, evidence, severity, and sizing.
[Testing](../Platform/Testing.md) owns coverage and tier decisions;
[UI test guidance](../../TrinketUITests/README.md) owns launch/entry and suite details.

## What to investigate

False-positive assertions, flaky failures, state leakage, unstable queries,
duplicated journey coverage, and setup/waits disproportionate to the outcome.
Trace failures through launch/reset seams, app testability, harnesses, and CI routing
when they contribute to the same cause. A slow test or long timeout is a lead,
not proof that shortening it is safe.

## Evidence and remedy

Show the failed/false signal, competing semantic owners, isolation violation, or
measured avoidable execution cost. Preserve every distinct consequential journey
that belongs at the UI tier. Move rule assertions to a cheaper existing owner when
it can prove the same invariant. Delete redundant/weak coverage or cases excluded
by the canonical keep/drop rubric, preserving valid unique outcomes.

Prefer stable entry and queries to timing/index assumptions. Remove sleeps or
shorten waits only when readiness is established and the supported failure timing
is preserved. Reuse existing harness/page objects; add a production seam only for
a confirmed testability boundary with no player-visible test behavior.

Verify the repaired journey and relevant isolation conditions, and report the
improved signal, flaky cause, tier fit, or measured runtime direction. A green rerun
alone does not explain a flaky failure or establish its cause is fixed.

## Boundaries

- UI tests use XCTest; package tests use Swift Testing under Testing.md.
- Follow the existing Play-map entry contract for mid-battle interactions; do not
  use extreme tick intervals to bypass it.
- Local UI runs are serial on one managed simulator within
  [Verification](../Platform/Verification.md)'s limits. Do not invent suite budgets
  or run full UI merely because this audit reviews its portfolio.
- Accessibility-setting UI tests remain outside [PD-014](../Product/Decisions.md).
  Stable identifiers required by an owned journey are in scope; broader shipping
  interaction defects belong to [16](16_UIInteractionFeedbackAudit.md).
- Unit/package test quality belongs to [17](17_UnitTestAudit.md).
