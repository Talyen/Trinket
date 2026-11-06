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

The original workstreams authorized publication, dispatch and confirmed failure
repairs; consolidation does not expand that authorization. The October 27
follow-through excludes user involvement and physical iPhone work. Live accounts,
cloud enablement, TestFlight deployment and release publication remain outside
this work. Device and service acceptance remains in [Player coverage](../Platform/PlayerCoverage.md),
[CloudKit gates](../Platform/CloudKitPreShipChecklist.md), and
[performance qualification](../Platform/PerformanceInvestigationPlaybook.md#device-qualification).

## Current priorities

| Priority | Next action and closure evidence |
|---|---|
| Required CI | Verify the committed State suite-filter repair and separate Smoke runner startup failures from product assertions. Complete generation, every package suite, Smoke, FullUI and unsigned device Release compilation on the intended revision. Run `ci.yml` with `toolchain=verified, scope=exhaustive-pilot`, then `toolchain=latest, scope=exhaustive-pilot`; report actual Xcode builds separately. The original exact candidate `27A9275` is not qualified by fallback or mixed-build results. |
| Ask to Buy denial/retry | Investigate the StoreKit test-service discrepancy below on a supported runtime and, when authorized, in sandbox. Keep denial, ownership and retry assertions; do not discard verified shipping entitlements based on test transaction IDs. |
| Player profiles | Complete the [iOS and iPadOS 26 and 27 matrix](../Platform/PlayerCoverage.md#ci-and-profiles) after native Settings preparation succeeds. Preserve individual failures and skips. Inspect rendered captures and accessibility results. |
| Extended play | Complete FullUI/profile/Soak and `player-coverage.yml` with `scope=all`. Preserve successful repeated-play/crash-recovery evidence without treating it as current-source or whole-portfolio qualification. Distinguish game duration from UI-query and scheduling delays before changing deadlines. |
| Localization | Complete talent-reward/compact-phone display, Options/Play navigation and rendered acceptance for every currently configured language. Earlier five-language and double-English passes do not cover the current language set. Check complete text and reachable controls; hittability alone does not establish visual acceptance. |

## Known diagnostic constraint

A StoreKit test reported a declined Ask to Buy transaction as failed while
`Transaction.currentEntitlements` returned it as verified and unrevoked. Investigate
on a supported runtime and, when authorized, in sandbox. Apple's
[guidance](https://developer.apple.com/documentation/storekit/testing-ask-to-buy-in-xcode)
says a declined request does not deliver a transaction. This observation does not
establish production behavior; preserve the denial, ownership, and retry assertions.

## Closure

Record exact revisions, candidate builds, executed selectors and individual skips.
Missing, cancelled or expired evidence cannot close a gate. Delete this plan when
the hosted acceptance work completes or its remaining actionable blockers have
been transferred to their owners. Run history belongs in retained deliverables,
not a growing permanent plan.
