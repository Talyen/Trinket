---
type: execution-plan
status: blocked
reason: Separate push authorization is required before validating the new hosted workflows.
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
- [ ] Review, run lightweight handoff, commit and integrate with the shared lock.
- [ ] Obtain separate push authorization for new hosted workflow validation.

Existing primary-main fixes for process inspection retries, simulator runtime
architecture, profile continuation and auto-end task awaiting must be preserved.
UI product changes require exact-build reproduction; seven-day observation cannot
be represented as completed by local checks.

## Hosted follow-up

The exact-build declined Ask to Buy reproduction is
[run 39052408277](https://github.com/Talyen/Trinket/actions/runs/39052408277),
using source run 39027879263 and its latest toolchain products. It does not validate
this branch's new harness. Product purchase behavior and accessibility checks remain
unchanged pending exact-build evidence.

After separate push authorization, push the reviewed task branch for immutable
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
