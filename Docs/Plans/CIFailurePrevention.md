---
type: execution-plan
status: active
created: 2026-10-17
updated: 2026-10-17
expires: 2026-10-24
---

# CI failure prevention

Implement the accepted October 14–17 CI review while preserving lightweight local
verification and the existing post-push workflow.

- [x] Preserve job diagnostics sessions, preparation phases and distinct verdicts.
- [x] Isolate native parity into hosted jobs with exact-run iOS execution receipts.
- [x] Complete bounded read-only preparation retries without weakening ownership.
- [x] Improve native Settings readiness and per-screen audit evidence.
- [x] Document atomic consumer/fixture migrations and deterministic assertions.
- [x] Review, run lightweight handoff, commit and integrate with the shared lock.
- [x] Obtain separate push authorization for new hosted workflow validation.
- [ ] Complete qualified and latest hosted qualification and Player coverage.
- [ ] Compare seven days of distinct failure signatures.

Existing primary-main fixes for process inspection retries, simulator runtime
architecture, profile continuation and auto-end task awaiting must be preserved.
UI product changes require exact-build reproduction; seven-day observation cannot
be represented as completed by local checks.

## Hosted follow-up

The exact-build declined Ask to Buy reproductions failed on both
[latest](https://github.com/Talyen/Trinket/actions/runs/39052408277) (source
39027879263) and [qualified](https://github.com/Talyen/Trinket/actions/runs/39053179787)
(source 39003902224) toolchains. Both fail reopening the Full Game offer after a
decline; retained screenshots show Warlock details instead. This confirms a
baseline failure, without establishing its cause or validating this branch's new
harness. No shipping purchase behavior or requested accessibility coverage changed.

The user authorized pushing the branch, hosted validation and seven-day follow-up.
Local integration at `577efc7e0` passed all 55 selected script suites and lightweight
handoff gates; Swift compilation and simulator journeys remain hosted checks.
The first full [qualified run](https://github.com/Talyen/Trinket/actions/runs/39054474255)
found an actor-transfer compiler error in the new audit helper. The helper uses no
test-instance state and is now static. Queued latest run 39054746972 and Player run
39054627132 were cancelled to restart on this correction; these cancellations are
not test failures and their requested coverage must be rerun in full.
The same run passed 1,006 Engine tests and exposed one Searing Bind fixture that
seeded effect ID 1 without advancing the allocator. Seed Burn through the existing
insertion helper; preserve the one-versus-two skipped-action assertions. The
combined control-extension lifecycle coverage passed and remains intact.
The original Content shard exhausted its budget following two slow simulator boots;
its infrastructure verdict retained the boot and retry evidence, without claiming
executed tests. State's retained session contains Core, Persistence and AppState
results together (65, 396 and 213 passed tests).
Player compatibility run 39055440293 failed before runtime import because blanket
runtime deletion encountered a watchOS image already being deleted. Replace that
cleanup with complete validated iOS-only image selection and retained phase/retry
receipts, preserving the disposable-runner guard and failing on mutation errors.
The baseline-build isolated smoke selector passed in run 39057528818. The corrected
full run 39055438737 still failed smoke during launch-readiness AX snapshotting;
its screenshot is empty, so neither a product cause nor a framework cause is proven.
The initial parity dependency also skipped valid Core evidence after unrelated unit
failures. Export each complete comparator even when another package fails, run
requested parity after failed shards, and require its result. Cancellation still
reports cancelled unless an original job failure exists; missing execution never
passes. Preparation inventory logs now retain each timed-out attempt on stderr.
Push the reviewed task branch for immutable
hosted qualification. Run `ci.yml` with `toolchain=verified`,
`scope=exhaustive-pilot` to exercise the full portfolio and new parity jobs without
reuse, followed by `toolchain=latest`, `scope=exhaustive-pilot`, and
`player-coverage.yml` with `scope=all`. Watch the exact revisions, fix scoped
regressions, and report required/advisory results separately. Keep iOS 18, compact,
iPad and Duo evidence distinct; native audits, layout and StoreKit outcomes require
hosted results, not script-test inference.

For seven days after the first pushed revision, compare distinct failure signatures
in required CI and advisory coverage separately. Exclude cancellations from failure
rates, count diagnostic repeats separately, and distinguish first attempts from
reruns. The October 14–17 baseline is 60 runs: 30 failed, 11 passed, 19 cancelled;
run-level overlapping signatures include four obsolete-API compilation failures,
three guest-inventory timeouts, five native-settings failures and five audit-timeout
failures. Do not treat those overlapping counts as independent defects. Arrange the
requested daily follow-up after push, keeping unchanged or non-actionable results
quiet and notifying on recurrence, completion, failure or required user action.
The thread follow-up `trinket-ci-seven-day-review` was created for October 18–24,
but the app subsequently reported it missing and its local record disappeared.
The user requested leaving it removed; do not recreate a scheduled follow-up.
Evaluate prevention only on revisions containing this implementation and its
hosted corrections; older remote-main runs remain baseline observations. Lack of
rollout or insufficient exposure cannot establish a reduction in failures.
