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
- [x] Review overlapping UI coverage and retain one effective owner per assertion.
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

## Qualification passed

Run 39354661539 passed at source 080ad3858 on Xcode 27.1 build 27A9275.
Exact native/iOS matches: Engine 1008 functions / 1106 parameterized cases;
Core 66 / 58; Content 283 / 288. No native or iOS comparator skips/failures.
Proof artifacts were downloaded and identities checked. Native Content may now be
activated only for 27A9275; 27A9269 retains iOS Content via build-specific metadata.
The standard baseline 39352744217 passed first attempt in 41.83 minutes. It included
13.32 minutes queueing before the 16.98-minute Battle job, then a 9.45-minute device
Release job (8.6 minutes compiler step). Do not call all that time compilation.
Fresh qualified baseline 39353417412 passed: 35.75 minutes overall, 11.52 queue,
24.17 executing, 18.15 UI; ten invocations, eleven methods, zero failures/skips.
Reports: /tmp/trinket-ci-speedup-baseline.json and
/tmp/trinket-ci-speedup-release-baseline.json. Native proof location is recorded in
/tmp/trinket-native-qualification-location.txt. Candidate final measurements pending.

## Active final benchmark

Activated candidate 95e44fad83e38e218cde22f8acb8bdf8f6b13b95.
First standard run: https://github.com/Talyen/Trinket/actions/runs/39358321807
This first run seeds the new package source-time receipts and device Release cache;
a second unchanged-source run must verify genuinely warm behavior.
Dispatch fresh candidate release only once this run publishes its app archive, so
product-only reuse is exercised while other required jobs remain in progress.
Preserve every required case and inspect actual backend logs and cache behavior.

Fresh candidate UI run: https://github.com/Talyen/Trinket/actions/runs/39358719618
(source 95e44fad8; app archive was already published and standard CI still running).
The next revision moves only the portable prepared-asset validators off macOS and
makes proof lookup use actual checkout HEAD for explicit older-source comparisons.
Keep those checks intact. Source asset validation uses Python stdlib only (hashes,
manifest IDs, generated outputs and lyric validation), with no Xcode/media encoder.
Verify its Linux job before final acceptance. The existing DesignSystem UIKit tests
remain on macOS/iOS. Re-run final standard after this revision to measure warmed
compiler state; use fresh UI source 95e44fad8 as batching evidence only unless a
final-revision fresh run also confirms all eleven cases and product reuse.

## First candidate infrastructure failure

Standard 39358321807 failed: Battle preparation spent 691 seconds booting/recovering
before its two serial packages. FeatureSupport 99 cases passed; BattleFeature
exhausted the remaining time with incomplete results. No passing claim for this run.
The same iOS 27 runtime/device booted normally in the baseline, so retain that
coverage. Limit admission of further CI recovery boots to a six-minute preparation
window and separate Support/Battle jobs so a failure cannot repeat passed support
tests. This is a retry budget, not a guarantee that every simctl call completes in
six minutes. Existing per-command/watchdog and guest ownership protections remain.
Fresh candidate UI 39358719618 remains in progress; inspect exact results before
claiming batching benefit. New Release/compiler caches still require a successful
final-source run and warm repeat.

Device Release also no longer waits for the slowest package job: it starts after
build/smoke releases its runner. Package results and Release remain independent
required CI OK inputs. This lets Release seed its compiler cache even if an
unrelated simulator package encounters infrastructure failure; it does not reuse
a failed test or weaken either check. The Linux asset move and removal of routine
native comparators offset this fan-out. Measure actual queue contention.

## Remaining serial and housekeeping costs

Source be1628b4d standard run 39361783708 now seeds cold Support/Battle and device
Release state. Battle 206 and Persistence 400 passed. The first fresh UI candidate
39358719618 passed exactly the baseline eleven methods, zero skips, in two
invocations; actual end-to-end 37.47m versus baseline 35.75m, not an improvement.
Its eight-minute cold-boot/recovery consumed the batching savings. Fresh be1628b4d
release run 39362370376 is active. Dispatch 39362361602 used a short SHA and was
cancelled before verification; exclude it from performance results.

Release has no input dependency on simulator compilation/results. Remove the
remaining build/smoke dependency too, preserving all independent CI OK requirements.
Also disable the existing local output age-prune knob only on disposable standard
and release runners. Battle's cache-save log demonstrated another timed-out full
process inventory; these local tenant scans have no retention value on fresh VMs.
Keep explicit cache pruning and fresh simulator/guest ownership checks. Measure
the next candidate rather than attributing all setup delays to that scan.

The pending f6401f3dd comparison 39363336507 was cancelled before starting: its
intentional wait behind the bootstrap run would contaminate end-to-end timing.
Dispatch the next full comparison only after bootstrap completes. No product
assertions changed. Add a five-minute per-method XCTest limit only to CI Smoke
and explicit qualified release methods; largest observed baseline method is 135s.
Existing thirty-minute invocation watchdogs alone permit one hung method to lose
the whole batch and its case diagnostics. Leave other FullUI/Soak/performance
allowances unchanged and treat timeouts as failures, never automatic product passes.
Xcode's installed -help confirms all three execution-timeout options.

Bootstrap Smoke passed all six methods, but guest inventory alone took 275s,
followed by 567s test wrapper time; these are actual recorded phases, not inferred
queue/compile time. Age-pruning is not the whole cause: first Content cache-save
age cleanup took only three seconds while its 148MB cache upload stalled. Record
host memory/swap counters after UI simulator boot in future runs before drawing
a resource-pressure conclusion. Fresh be1628b4d UI 39362370376 failed boot within
the bounded preparation window, as intended; it provides no passing coverage.

## AppState scheduler starvation

Bootstrap State 39361783708 failed, not passed: compact timing was absent because
the bundle did not finalize. Raw artifact proves six FullGameStoreTests exceeded
the suite's 60s limit, cancelling them and causing fourteen subsequent ownership
assertions to fail. Total package execution was 81.6s while unrelated MainActor
work ran. Preserve the seven purchase functions, all ownership assertions and
the 60s limit. Dispatch that suite separately, then all other AppState suites with
an explicit exclusion on the same runner. No product Swift or assertion changes.
Verify the two fresh executed method sets are disjoint and their union equals
the original 213 functions (212 passing plus the conditional worker skip).

## Unbounded matrix scheduling

Controlled candidate 7e47425e4 run 39364870817 has verified warm Release compilation
(about 90s versus baseline 516s) and passed Support/Content/Core. Build/smoke waited
over eight minutes while the unit matrix filled all observed macOS capacity.
The extra package splits need a fan-out limit: cap the unit matrix at three,
retaining capacity for build/smoke and other required jobs. Complete the current
run, then measure the capped run without intentional workflow-concurrency waiting.
This comparison still uses the unchanged baseline game source. Current local main
also has two separate battle changes (b419dc188, 937b290b9); incorporate/review
those later, then verify the combined result without presenting new game tests
as part of the controlled timing comparison. No main push is authorized.

The 7e47425e4 State job passed both scopes: seven purchase functions, zero skips,
then 205 passing functions plus the same conditional worker skip. The downloaded
method/result/argument multisets have exactly the original 213-function union
and zero duplicate executions. No one-minute purchase deadline was increased.
Evidence location: /tmp/trinket-state-partition-location.txt. The extra invocation
has startup cost; count its complete job time in the overall comparison.

The six-minute recovery admission default remains for standard lanes. For the
downloaded qualified 26.2 runtime, use an explicit twelve-minute window: the old
95e44fad8 fresh run recovered after a cold-boot timeout and passed all eleven,
whereas the six-minute guard made be1628b4d fail before testing. Preserve that
bounded recovery instead of counting early failure as speed. Add override/exhaustion
cases to the existing ownership-safe shell regression. Full fresh UI cost still
needs measurement on the final candidate.

## Staged admission comparison

The uncapped 7e47425e4 run 39364870817 failed Smoke readiness (five passed, one
failed, zero skips). Screenshot and AX tree show Battle Hand and three card buttons
after the readiness check timed out. Keep all UI assertions and the ten-second
check unchanged. It is excluded from speedup results. Hosted telemetry confirms
three CPUs and 7 GiB RAM; that alone does not prove the cause of the AX delay.
The capped 07957c81d run 39367662655 started app/smoke in sixteen seconds instead
of nine minutes. Its remaining matrix tail is still pending.

Prepare a staged alternative: Engine/Core run first, leaving initial room for
app/smoke, gate and Release; after their short stage succeeds, admit up to five
remaining package jobs. Reuse identical steps/env through GitHub-supported YAML
anchors, preserving job names, cache namespaces, proofs and comparator owners.
Selected package sets must remain disjoint and complete for every path scope.
A failed logic stage must not suppress remaining simulator evidence or pass CI OK.
Measure this alternative against the capped complete result before choosing it.

The capped 07957c81d run 39367662655 passed all six Smoke methods, including the
unchanged ten-second retreat readiness assertion. It failed the final Battle
preparation instead: boot began 04:19:40, reported complete at 04:24:27 (287s),
and the 240s watchdog reported failure after its child-process cleanup at 04:24:40.
No Battle case executed. Preserve the six-minute standard setup admission window
and existing job deadlines, but allow 300 seconds for the cold-boot command;
ordinary boots do not wait longer. Preserve explicit timeout overrides and local
150s behavior. This is startup calibration, not measured speedup; run the staged
candidate to completion and compare only complete passing scopes.

The existing infrastructure rerun helper also misclassified 39367662655: it
required CI OK itself to have a UI/unit name before reading the failed Battle
preparation evidence. Ignore only the recognized derived aggregate for evidence
classification; --failed still reruns it. Require infrastructure evidence for
every concrete failed job and retain the product/compiler veto. Verify the real
boot-only failure is eligible and the 7e47425e4 readiness assertion is not. Any
manual recovery after this investigation is correctness/recovery evidence, not
a clean timing sample (its wall clock includes the human investigation pause).


## Staged result and crash evidence

Run 39371306539 at 60e1e8e7f passed every package, generation/style, prepared asset
and device Release checks. AppState exactly matched baseline 212 passed plus the
same one worker-only skip; Persistence exactly matched all 400 cases. Smoke
failed: five passed, one failed, zero skips. FullGamePurchaseSmokeTests first
StoreKit registration launch pid 31860 exited with signal 11 at 04:57:50, before
the helper attempted termination. The next launch completed the purchase and
Warlock assertions, but XCTest correctly retained the setup crash failure.
The exported xcresult diagnostics contain no crash report/stack, only the signal
in the session log. No product or test assertion change is justified from this.
Exclude this run from passing speedup claims. Enable explicit failure-only Xcode
diagnostics for the already bounded hosted smoke/release methods, then repeat
full standard scope; a recurrence must retain its cause. Do not automatically
classify or rerun the app crash as simulator infrastructure.
