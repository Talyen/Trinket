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
- [ ] Run unchanged baseline CI and qualified release verification on the task branch.
- [ ] Batch release UI without losing case execution proof or passed checkpoints.
- [ ] Separate product transfer proof from full standard verification proof.
- [ ] Remove serial package retry duplication and repair package incremental inputs.
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
