---
type: execution-plan
status: active
created: 2026-10-09
updated: 2026-10-27
expires: 2026-11-03
---

# Hosted CI and player acceptance

## Objective and boundaries

Finish hosted reliability, player coverage and localization acceptance on a named
revision with proven executed scope. Follow [Verification](../Platform/Verification.md)
and the [toolchain ladder](../../Scripts/Reference.md#toolchain-ladder).

The original October 9, 14 and 15 workstreams authorized publication, dispatch and
confirmed failure repairs; consolidation does not expand that authorization.
The October 27 follow-through excludes user involvement and physical iPhone work.
Live accounts, cloud enablement, TestFlight deployment and release publication
remain outside this work. Device/service acceptance stays in
[Player coverage](../Platform/PlayerCoverage.md),
[CloudKit gates](../Platform/CloudKitPreShipChecklist.md) and
[performance qualification](../Platform/PerformanceInvestigationPlaybook.md#device-qualification).

## Current priorities

| Priority | Next action and closure evidence |
|---|---|
| Required CI | Verify the committed State suite-filter repair and separate Smoke runner startup failures from product assertions. Complete generation, every package suite, Smoke, FullUI and unsigned device Release compilation on the intended revision. Run `ci.yml` with `toolchain=verified, scope=exhaustive-pilot`, then `toolchain=latest, scope=exhaustive-pilot`; report actual Xcode builds separately. The original exact candidate `27A9275` is not qualified by fallback or mixed-build results. |
| Ask to Buy denial/retry | Investigate the StoreKit test-service discrepancy below on a supported runtime and, when authorized, in sandbox. Keep denial, ownership and retry assertions; do not discard verified shipping entitlements based on test transaction IDs. |
| Profiles and compatibility | Complete phone/iPad, compact, iOS 18 and Duo evidence after native Settings preparation succeeds. Preserve individual required/advisory failures and skips; inspect rendered captures and accessibility results. |
| Extended play | Complete FullUI/profile/Soak and `player-coverage.yml` with `scope=all`. Preserve successful repeated-play/crash-recovery evidence without treating it as current-source or whole-portfolio qualification. Distinguish game duration from UI-query and scheduling delays before changing deadlines. |
| Localization | Complete talent-reward/compact-phone display, Options/Play navigation and rendered acceptance for every currently configured language. Earlier five-language and double-English passes do not cover the current language set. Check complete text and reachable controls; hittability alone does not establish visual acceptance. |

## Evidence reviewed October 27

- [CI 40618476959](https://github.com/Talyen/Trinket/actions/runs/40618476959)
  on `281495366` passed generation/style and Core, Support, Content, Persistence,
  Engine and Battle package tests. State failed suite execution-proof validation;
  current source explicitly recognizes the disabled Playthrough worker in that
  filtered lane. Smoke's runner terminated while preparing tests, without a
  product assertion. Release, assets and FullUI were skipped. This is not a pass.
- [Player 40619526988](https://github.com/Talyen/Trinket/actions/runs/40619526988)
  passed repeated play and crash recovery; profiles and iOS 18 failed. Subsequent
  committed navigation/Settings fixes still need completed hosted evidence.
- [Purchase diagnostic 40628543053](https://github.com/Talyen/Trinket/actions/runs/40628543053)
  used a temporary debug probe at `e1d704e66`. After decline, StoreKitTest reported
  transaction 0 as failed, while `Transaction.currentEntitlements` returned the
  same transaction as verified and unrevoked; the app consequently granted access.
  The assertion failed before the retry. Apple's [Ask to Buy test guidance](https://developer.apple.com/documentation/storekit/testing-ask-to-buy-in-xcode)
  says a declined request does not deliver a transaction. This establishes a test
  environment discrepancy, not the cause of any production behavior; the probe is
  not part of main. The assertion helper preserves caller file/line for future failures.
- At review, [CI 40626255246](https://github.com/Talyen/Trinket/actions/runs/40626255246)
  and [Player 40626286291](https://github.com/Talyen/Trinket/actions/runs/40626286291)
  for `ff757539e` were queued. Check their actual state before scheduling redundant
  work. Queueing is not execution or qualification; newer local commits also need
  their own applicable verification.

Downloaded failure logs and the purchase xcresult/captures are retained with this
task's `PlanReview` deliverables. Older evidence and authorization details remain
in Git at `ba6aa1277:Docs/Plans/CIHostedVerification.md`; check artifact retention
before relying on remote historical results. Historical Development CloudKit,
localization, simulator and release-build passes remain historical successes,
not current shipping qualification.

## Deliberately retired work

The obsolete seven-day CI comparison, workflow benchmarking, unimplemented rename,
and speculative resource experiments are cancelled.
Their plan revisions remain in Git. The updated [storage plan](StorageLifecycle.md)
retains concrete ownership questions for protected release artifacts. Existing
cleanup safety, known workflow
friction and permanent release gates remain in their canonical owners. No device
requirement is marked verified by retiring its investigation plan.

## Closure

Record exact revisions, candidate builds, executed selectors and individual skips.
Missing, cancelled or expired evidence cannot close a gate. Delete this plan when
the hosted acceptance work completes or its remaining actionable blockers have
been transferred to their owners. Run history belongs in retained deliverables,
not a growing permanent plan.
