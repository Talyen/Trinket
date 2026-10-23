---
type: execution-plan
status: active
created: 2026-10-17
updated: 2026-10-23
expires: 2026-10-24
---

# CI failure prevention

## Objective and boundaries

Complete the accepted October 14–17 CI reliability review and seven-day comparison.
Preserve preparation diagnostics, native parity proof, bounded read-only retries,
native Settings evidence, atomic consumer/fixture migration and deterministic assertions.
Local integration `577efc7e0` passed the 55 selected script suites and lightweight
gates; hosted qualification and observation remain outstanding. The original task
authorized branch publication, hosted validation and seven-day follow-up.

## Recorded blockers

Exact-build declined Ask to Buy diagnostics failed on
[latest](https://github.com/Talyen/Trinket/actions/runs/39052408277) (source
39027879263) and [qualified](https://github.com/Talyen/Trinket/actions/runs/39053179787)
(source 39003902224): Warlock details appeared instead of the reopened offer.
This establishes a baseline failure, not its cause or new-harness validation.
Do not change shipping purchase behavior without exact-build evidence.

The first new [qualified run](https://github.com/Talyen/Trinket/actions/runs/39054474255)
exposed an actor-transfer compiler error in the audit helper and an effect-ID
allocator mismatch in the Searing Bind fixture. The helper is now static and the
fixture uses the existing insertion helper, preserving its one/two skipped-action
assertions. Engine otherwise passed 1,006 tests, including control-extension lifecycle
coverage. Queued latest `39054746972` and Player `39054627132` were cancelled for
correction; their coverage still needs execution.

## Remaining work

- [ ] Publish the reviewed corrections and run `ci.yml` with
  `toolchain=verified, scope=exhaustive-pilot`, then
  `toolchain=latest, scope=exhaustive-pilot`, and
  `player-coverage.yml` with `scope=all`. Follow exact revisions and report
  required/advisory, iOS 18, compact, iPad and Duo evidence separately.
- [ ] Compare seven days of distinct failure signatures after the first pushed
  implementation. Separate required/advisory lanes, first attempts/reruns and
  diagnostic repeats; exclude cancellations from failure rates. Insufficient
  exposure cannot establish prevention.
- [ ] Resolve whether to recreate `trinket-ci-seven-day-review`: it was created for
  October 18–24, then the app reported it missing and its local record disappeared.
  Clarification remains required before recreating a possibly user-deleted follow-up.
  Keep unchanged/non-actionable results quiet; notify on meaningful recurrence,
  completion, failure or required action.
- [ ] Reconcile durable guidance and delete this plan when acceptance is complete.

## Comparison baseline

The October 14–17 baseline has 60 runs: 30 failed, 11 passed, 19 cancelled.
Overlapping run-level signatures include four obsolete-API compilation failures,
three guest-inventory timeouts, five native-settings failures and five audit-timeout
failures; they are not independent defects. Compare only revisions containing
this implementation and its hosted corrections; older remote-main runs remain
baseline observations. Preserve process-inspection retries, runtime architecture,
profile continuation and auto-end task awaiting. Earlier attempts remain in Git history.
