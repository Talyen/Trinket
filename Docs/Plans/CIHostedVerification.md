---
type: execution-plan
status: active
created: 2026-10-09
updated: 2026-10-25
expires: 2026-10-23
---

# Hosted CI and player acceptance

## Objective and boundaries

Complete the overlapping hosted reliability, real-player coverage, and localization
acceptance work through one shared execution list. This consolidates the former
PlayerCoverage and LocalizationReleaseValidation plans without closing their work.
Dated observations below were retained, not refreshed against current main. Earlier
PlayerCoverage and LocalizationReleaseValidation revisions remain at their original
paths in Git; pre-consolidation copies are retained with this task's deliverables.

| Workstream | Original authorization and acceptance boundary |
|---|---|
| Hosted reliability (October 14) | Pushes, workflow dispatches, and confirmed failure repairs; preserve assertions and exact-build qualification. Live service enablement is excluded. Recorded candidate: `27A9275` in every requested lane; fallback/mixed-build evidence cannot qualify it. |
| Player coverage (October 9) | Review, repairs, integration, push and CI follow-through for seven approved coverage areas. Preserve card play, saves, artwork and sound. Live accounts, sync enablement and deployment are excluded. |
| Localization validation (October 15) | Branch push and exhaustive CI after pseudolocalization investigation. Finish localized talent-reward and compact-phone display verification; artwork lettering and release publication are excluded. |
| CI failure prevention (October 14–17) | Separate [plan](CIFailurePrevention.md) retains its authorization, seven-day comparison, and missing-follow-up decision; shared qualification and blockers are tracked here. |

Consolidation changes neither those boundaries nor the current documentation task's
scope. Resume under current [Verification](../Platform/Verification.md) and
[toolchain policy](../../Scripts/Reference.md#toolchain-ladder), retaining each
workstream's exact-revision/candidate requirements. Local diagnostics stay bounded.

## Shared execution

All rows remain open in the recorded evidence. One qualifying run may satisfy
multiple workstreams only when its revision, candidate, selectors and actual
executed scope meet each requirement. Missing, skipped, cancelled, timed-out or
expired evidence cannot close a row.

| Open gate | Required work and evidence |
|---|---|
| Combined source and publication | Reconcile each workstream's committed repairs with current main; complete review, handoff and local integration before publishing the authorized follow-up. Include the relocated diagnostic driver, player-profile repairs and localized test-import repairs described below. |
| Exact-candidate qualification | Complete generation, package tests, Smoke, FullUI and unsigned device Release compilation for the intended revision. Failure prevention requests `ci.yml` with `toolchain=verified, scope=exhaustive-pilot`, then `toolchain=latest, scope=exhaustive-pilot`. Missing candidate installations block qualification. |
| Compatibility and profiles | Complete phone/iPad profiles, iOS 18, compact and Duo evidence; report required/advisory outcomes and individual skips separately. Native Settings preparation and validated product stamps must succeed before dependent product assertions. Inspect screenshots, hierarchies and accessibility results. |
| Repeated play and recovery | Finish FullUI/profile/Soak acceptance and repeated-play/crash recovery against proven retained products. Failure prevention requests `player-coverage.yml` with `scope=all`. Distinguish battle duration, scheduling and UI-query delay before changing deadlines. |
| Localized UI | Finish talent-reward/compact-phone display checks and Options/Play exhaustive navigation. Review complete rendered text and reachable controls under the localization acceptance section; retain current-language gaps. |
| Purchase denial and retry | Reproduce the [declined Ask to Buy blocker](#declined-ask-to-buy) against qualified products before changing shipping purchase behavior; preserve ownership and denial/retry assertions. |

## Hosted reliability acceptance

Push [38683089222](https://github.com/Talyen/Trinket/actions/runs/38683089222)
at `3aa1a69e5` passed required CI after the external-save-generation fixture repair.
The newer combined range still needs hosted generation, compilation and tests.
Runner selection observed preferred `27A9275` and qualified fallback `27A9269`;
that mixed-build result cannot qualify one exact candidate.

Player [38681171142](https://github.com/Talyen/Trinket/actions/runs/38681171142)
passed iOS 18 Smoke, purchases, recovery, 394 Persistence tests and headless
career/settlement cohorts. Soak stopped on its fourth audio-enabled Contract;
the screenshot shows Victory while query latency rose near the existing deadline.
Largest-text profiles also failed accessibility/Continue scrolling: the helper
selected a nested carousel instead of Continue's outer scroll view.
The diagnostic workflow's relocated-driver/dependency repair passed 14 regressions
and admits the existing Soak plan; publication and exact-product execution remain pending.

Repair/verify Continue's outer scroll ancestry without weakening scroll counts or
visibility assertions. The exact candidate and remaining phone/iPad, compatibility
and recovery gates are tracked in the shared list.

Player artifacts `11949007677` (Soak) and `11949777170` (profile screenshots/traces)
identify the original failures; check retention before reuse. Earlier attempts and
superseded queued runs remain in Git history. Native Reduce Motion preparation
must succeed before dependent assertions run. Preserve execution proof,
accessibility scope and all product assertions. Use
[Verification](../Platform/Verification.md) for current local/hosted selection;
older notes deferring all local compilation do not override it.

## Player coverage acceptance

Lifecycle/rapid-input, reward interruption, mode navigation, haptics/StoreKit,
native settings, real-backend audio, serial Soak, fixed-seed careers and populated
schema-two migration/recovery coverage were implemented. Their standing scope and
remaining device/service gates live in
[Player coverage](../Platform/PlayerCoverage.md).

Required push [37978887013](https://github.com/Talyen/Trinket/actions/runs/37978887013)
on `5dc0e104` passed all seven Smoke cases. Extended
[37979415382](https://github.com/Talyen/Trinket/actions/runs/37979415382)
passed package, parity, assets, generation/style and unsigned device Release checks;
FullUI had 13 passes and 11 failures. Player
[37979418399](https://github.com/Talyen/Trinket/actions/runs/37979418399)
passed twenty careers and interruption/recovery workers but lacked completed
profile evidence. These are historical results, not verification of current main.

Reconcile `508a3b23` (missing Explore entry for Soak/audio/Spires) and repairs to
navigation, sheet dismissal, queries, switches and restore fixtures before the
follow-up. Verify invisible native titles and offscreen Settings rows at large
text, preserving settings restoration and aborting dependent assertions when a
prerequisite fails. FullUI/profile/Soak acceptance remains open; live device/service
qualification is separate under the standing Player coverage guide.

Coverage already protects draw followups, overlapping casts, finishing taps,
failed claims and stale callbacks; extend only confirmed gaps. Verify actual
repository artifact retention before relying on workflow requests: the original
run's repository cap shortened retention. Current retention policy lives in
[the command reference](../../Scripts/Reference.md#output-retention).

## Localization acceptance

Talent inspector scrolling, Campaign footer reflow, complete purchase labels,
Restore reachability, computed-action extraction and failure attachments were
repaired. Normal German/French and largest-text journeys passed for the five
languages then configured. Simulator and unsigned device Release archives passed
extraction and bundled-language checks. These historical results establish neither
current-language coverage nor network-disabled play or hardware purchase approval.

All five language journeys plus double English have individual hosted passes on
`665c4bfd8`; that run did not complete the full portfolio. The latest recorded
follow-up, [38843703793](https://github.com/Talyen/Trinket/actions/runs/38843703793)
on `c541a8962`, built the app but exposed moved-profile initializer access in
existing tests. The owning-module test imports were repaired in 35 files
(33 Engine, one BattleFeature, one Content); compile-only checks passed, including
Engine/BattleFeature on `34804bb57`. Hosted execution remains outstanding.

The shared execution list retains exact-commit package, Smoke, exhaustive UI and
device Release acceptance. Options and Play navigation lack completed exhaustive
evidence. Historical locale passes do not close current-language or device gaps.

Retained captures and compile/probe output were placed under
`/tmp/trinket-localization-release-validation/` outside the task checkout; confirm
availability before relying on them or cleaning up. The original full-portfolio
[run](https://github.com/Talyen/Trinket/actions/runs/38831028218) records package,
Smoke and per-language outcomes separately from budget-limited work.

[Localization](../Platform/Localization.md#pseudolanguage-diagnostics) owns the
Foundation double-string format artifact and native tab-caption crowding limits.
Keep real-language defects separate from synthetic stress behavior. Screenshot
hittability alone does not prove complete rendered text or an unobscured control.

## Shared blockers

### Declined Ask to Buy

Exact-build declined Ask to Buy diagnostics failed on
[latest](https://github.com/Talyen/Trinket/actions/runs/39052408277) (source
39027879263) and [qualified](https://github.com/Talyen/Trinket/actions/runs/39053179787)
(source 39003902224): Warlock details appeared instead of the reopened offer.
This establishes a baseline failure, not its cause or new-harness validation.
Do not change shipping purchase behavior without exact-build evidence.

The earlier isolated [localization diagnostic](https://github.com/Talyen/Trinket/actions/runs/38837629489)
reproduced the same Warlock-details symptom in a fresh process. Local probes differ
between iOS 27 and 26.2. Reproduce against qualified products before changing
purchase behavior; preserve ownership/denial assertions and follow
[StoreKit qualification](../Platform/Release.md#testflight-troubleshooting).
Shared blocker evidence lives here; each workstream retains its acceptance and
authorization above or in the linked failure-prevention plan.

### New harness validation

The first new [qualified run](https://github.com/Talyen/Trinket/actions/runs/39054474255)
exposed an actor-transfer compiler error in the audit helper and an effect-ID
allocator mismatch in the Searing Bind fixture. The helper is now static and the
fixture uses the existing insertion helper, preserving its one/two skipped-action
assertions. Engine otherwise passed 1,006 tests, including control-extension lifecycle
coverage. Queued latest `39054746972` and Player `39054627132` were cancelled for
correction; their coverage still needs execution.

## Closure

Preserve needed artifacts and record exact outcomes and individual skips in the
handoff. Update canonical owners only for confirmed behavior changes. Delete this
plan when all three acceptance workstreams and shared qualification dependencies
are complete or their unresolved work has been explicitly transferred. The
failure-prevention plan's comparison and follow-up decision remain separate.
