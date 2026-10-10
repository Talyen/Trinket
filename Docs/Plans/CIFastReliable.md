---
type: execution-plan
status: active
created: 2026-10-09
updated: 2026-10-09
expires: 2026-10-23
---

# CIFastReliable

## Objective

Reduce failed-CI diagnosis cost and routine verification effort without adding
workers or weakening required gameplay, persistence, or UI proof. Commit and
push the accepted recommendations and qualify their hosted behavior.

## Plan

- [x] Record the 9d6069e4 baseline: standard CI 19m21s, Engine 7m44s,
  State 16m42s, smoke/build 18m59s. Core test bodies measured 0.18s versus
  237s wrapper wall time; Engine bodies measured 4.37s versus 197s.
- [x] Add exact-build, selected-case diagnostic dispatch. Preserve the original
  failure and reject incompatible, missing, expired, or mismatched products.
- [ ] Qualify native Engine and Core coverage against iOS on the same revision;
  retain iOS parity in manual/nightly verification.
- [x] Reduce measured State/smoke overhead using native pure logic where qualified
  and narrow test-specific costs. Preserve all supported interaction coverage.
- [x] Give each job a bounded execution deadline with reserved diagnostic time;
  preserve timeout failures and terminate only owned child work.
- [ ] Add consequential script regressions; run scoped handoff and final review.
- [ ] Commit/push, inspect final standard and qualification jobs, compare timings,
  update canonical owners, and delete this plan.

## Constraints and evidence

- Work on primary main and preserve unrelated edits; initial checkout was clean.
- No new workers and no silent assertion retries or cross-commit product reuse.
- Native qualification must prove actual execution and comparable scope; positive
  test counts alone do not prove parity. Keep balance sweeps outside routine Engine.
- Core joins native qualification because current timings demonstrate a concrete
  State bottleneck. Persistence/AppState retain simulator verification unless
  separate equivalent proof justifies a change.
- Existing simulator preparation has one owner. Do not restore asynchronous preboot.

## Implementation evidence

- Local Engine 850 and Core 57 native function identities/results match the
  baseline iOS comparator. Hosted qualification will require new commit-linked
  timing receipts and retain both platforms' execution evidence.
- The combined purchase journey passed locally with chapter rejection/return,
  Options purchase, and recruited-Warlock detail assertions retained.
- The diagnostic workflow copies its driver before checking out the source run's
  SHA, allowing older compatible products to be diagnosed without rebuilding.
- Native-only Engine caches omit simulator products. Cache identity reuses the
  already-selected Xcode version/build while preserving existing key hashes.
- Real deadline fixtures prove expired work never starts, active owned work is
  terminated, and unrelated processes survive. Timeout receipts remain failures.

- Superseded the console-verdict-only native pilot fixture with stronger structured
  execution/discovery/parity regressions, retaining zero-test and failed-process
  rejection. Native and CI dispatch entrypoints join the resource-policy guard.
- iOS Core's public test tree exposes 43 Arguments nodes. Qualification now also
  compares expanded case counts and results; local Core matched 57 functions/43
  expanded arguments. Comparator cleanup is deferred until parity finishes.

## Hosted qualification gate

The first implementation push retains iOS package execution and compares native
Engine/Core in those same jobs, including expanded argument cases. Native push
routing and native-only caches remain inactive until that hosted proof agrees.
Then activate the dispatcher/native cache, restore parity to manual/nightly runs,
and verify the standard, focused qualification, and diagnostic dispatch paths.
