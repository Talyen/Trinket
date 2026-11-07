---
type: execution-plan
status: active
created: 2026-10-09
updated: 2026-11-07
expires: 2026-11-20
---

# Hosted CI and player acceptance

## Objective and boundaries

Finish hosted reliability, player coverage and localization acceptance on a named
revision with proven executed scope. Follow [Verification](../Platform/Verification.md)
and the [toolchain ladder](../../Scripts/Reference.md#toolchain-ladder).

The November 7 [App Store launch authorization](AppStoreLaunch.md) supersedes
the older scope exclusions and fixed-runtime qualification requirements. Adapt
CI to installed runner capabilities, with reduced coverage permitted and every
gap reported. Device and service acceptance remains in [Player coverage](../Platform/PlayerCoverage.md),
[CloudKit gates](../Platform/CloudKitPreShipChecklist.md), and
[performance qualification](../Platform/PerformanceInvestigationPlaybook.md#device-qualification).

## Current priorities

| Priority | Next action and closure evidence |
|---|---|
| Required CI | Verify generation, portable native tests, available simulator suites, Smoke, FullUI assessment and unsigned device Release compilation on the intended revision. Use installed Xcode/runtime choices; exact-candidate and native-parity checks remain optional diagnostics. Keep actual compiler and executed scope identifiable. |
| Ask to Buy denial/retry | Keep the assertion available for qualified-runtime diagnostics and live sandbox acceptance. Defer the known defective simulator case on other builds without changing signed ownership behavior. |
| Player profiles | Run the [adaptive iPhone/iPad portfolio](../Platform/PlayerCoverage.md#ci-and-profiles), retain substitutions and unavailable scope, and inspect rendered captures and accessibility results. |
| Extended play | Complete FullUI/profile/Soak and `player-coverage.yml` with `scope=all`. Preserve successful repeated-play/crash-recovery evidence without treating it as current-source or whole-portfolio qualification. Distinguish game duration from UI-query and scheduling delays before changing deadlines. |
| Localization | Ordinary FullUI covers English plus one rotating configuration to fit runner resources; reports identify deferred selectors. Use `full-localization=true` for the complete diagnostic matrix. Candidate rendered acceptance must state the actual language set reviewed. Check complete text and reachable controls; hittability alone does not establish visual acceptance. |

## Known diagnostic constraint

A StoreKit test reported a declined Ask to Buy transaction as failed while
`Transaction.currentEntitlements` returned it as verified and unrevoked. Investigate
on a supported runtime and, when authorized, in sandbox. Apple's
[guidance](https://developer.apple.com/documentation/storekit/testing-ask-to-buy-in-xcode)
says a declined request does not deliver a transaction. This observation does not
establish production behavior; preserve the denial, ownership, and retry assertions.

## Closure

Record exact revisions, candidate builds, executed selectors and individual skips.
Missing, cancelled or expired assessments cannot close a gate; an explicit
capability gap is accepted under the current policy and is not passing coverage. Delete this plan when
the hosted acceptance work completes or its remaining actionable blockers have
been transferred to their owners. Run history belongs in retained deliverables,
not a growing permanent plan.
