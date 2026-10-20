---
type: execution-plan
status: active
created: 2026-10-19
updated: 2026-10-19
expires: 2026-11-02
---

# CI end-to-end speedup

## Objective

Repair existing CI orchestration and reuse gaps, preserve consequential game,
save, purchase and release evidence, remove duplicate executions, and measure
hosted end-to-end duration before claiming completion.

## Plan

- [x] Inspect existing optimizations and distinguish first attempts from reruns.
- [x] Obtain authorization to push only the task branch and dispatch comparisons.
- [x] Start unchanged baseline CI and qualified release verification on the task branch.
- [x] Batch release UI without losing case execution proof or passed checkpoints.
- [x] Separate product transfer proof from full standard verification proof.
- [x] Remove serial package retry duplication and repair package incremental inputs.
- [ ] Review overlapping UI coverage and retain one effective owner per assertion.
- [ ] Verify locally, then compare hosted runs with matching scope/toolchain/profile.
- [ ] Review and integrate under the shared lock; preserve hosted limitations.
- [ ] Update canonical policy, remove this plan only after measured verification.

## Evidence and limits

Baseline source: e53534f80. Historical 39156095962 and 39166829256 include failed
first attempts and reruns, not 26-minute job queues. First failure was an AppState
invocation timeout; the other was a Merchant UI snapshot timeout. Do not report
rerun time as queue time or cache hits as a speedup. Actual assertions, skipped
cases, first attempts, reruns, preparation and artifacts must remain distinguishable.
The unrelated CIHostedVerification and CIFailurePrevention plans remain untouched.

Baseline branch commit 497c890269057427e0a1769ff1a40790f4c602d4 changes only this plan.
CI: https://github.com/Talyen/Trinket/actions/runs/39352744217
Qualified release: https://github.com/Talyen/Trinket/actions/runs/39352747019
Both were dispatched together. A fresh-evidence release comparison is also needed
if this baseline restores already-passed selectors. Push only codex/ci-end-to-end-speedup;
main pushes and deployment remain outside this authorization.

Initial repair also gives unsigned device Release compilation its own warm cache.
All existing game tests remain; duplicate save execution on app-state reruns and
repeated XCTest setup are removed instead of deleting consequential assertions.
The first full lightweight handoff passed all script regressions, docs and cheap
gates. Neither that result nor implemented changes establish a speedup.

## Published comparison

Repair candidate: 214c44571abb7ab527120f2fba7d8719cc996945.
Candidate standard CI: https://github.com/Talyen/Trinket/actions/runs/39353415213
Fresh baseline release (new workflow, unchanged source 497c89026):
https://github.com/Talyen/Trinket/actions/runs/39353417412
Fresh candidate release:
https://github.com/Talyen/Trinket/actions/runs/39353451320
The initial cache-eligible baseline release 39352747019 was intentionally cancelled
in favor of forced fresh evidence; exclude it from pass/failure and speedup statistics.
Both fresh runs share the same workflow definition but checkout their explicit source
commit. They bypass saved journey evidence and preserve the same qualified runtime,
Smoke methods and critical selectors. Inspect actual method IDs, not just totals.

## Follow-up from baseline timing

The baseline Content job passed 283 content cases with only 7.6 seconds of measured
assertion time but 13 minutes job duration. Add Content to the existing native/iOS
qualification harness; do not route its routine checks natively before same-revision
qualification passes. Keep all DesignSystem asset/color checks on iOS. Existing
Engine/Core native dispatch now applies to standard verified manual runs as well
as pushes; latest/nightly/exhaustive/qualification retain iOS comparisons.
Intermediate pending runs 39353415213 and 39353451320 were superseded/cancelled,
not failed measurements. Standard candidate 39353809022 uses 7a66f1e6d but is still
pending behind baseline; supersede it with qualification before activating Content.
The original baseline standard 39352744217 must finish; do not cancel it.

Qualification candidate 080ad3858 supports Content but does not activate it.
Qualification run: https://github.com/Talyen/Trinket/actions/runs/39354661539
It waits behind the unchanged baseline standard run. Native Content activation
must be bound to the exact qualified Xcode build(s), or retain iOS Content on an
unqualified fallback build. Config currently admits 27A9275 and 27A9269.
After qualification, activate Content, run final standard and fresh qualified UI,
then repeat standard to measure a genuinely warm device Release cache. Do not
claim completion from the first cold run or the existing lightweight passes.

The DesignSystem inventory guard was reviewed and retained: it ensures newly
added colorsets enter the dark/light runtime-resolution test's discovery list.
Its surviving four other functions alone would miss an unregistered colorset;
removing that guard would reduce real coverage for negligible time saved.
Baseline State: Core 66 passed (111s wrapper), Persistence 400 passed (213s),
AppState 212 passed/1 existing skip (174s). Baseline Smoke: six passed, no skips;
327s test wrapper, 128s boot and 47s guest bookkeeping. Use actual artifact method
IDs for comparisons, not total duration or test counts alone.
