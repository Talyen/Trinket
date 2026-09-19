---
type: execution-plan
status: blocked
reason: Physical-device profiling is unavailable and host Instruments cannot attach to the live Simulator app.
created: 2026-09-19
updated: 2026-09-19
expires: 2026-10-03
---

# ScrollPerformanceInvestigation

## Objective

Investigate Collection, shared pickers, Campaign/Explore, Homestead, and Battle
using repeated optimized measurements. Apply only trace-supported optimizations
without changing appearance, save ownership, artwork budgets, or gameplay timing.

## Plan

- [x] Inspect ownership, container choices, artwork scheduling, and existing scenarios.
- [x] Run the broad optimized baseline with two requested repetitions (43/80 reports;
  interrupted journeys retained as failures, not accepted coverage).
- [x] Sample Collection, equipment, Contracts, and Homestead; distinguish XCTest
  accessibility work from app work. No measured case for a container/model rewrite.
- [x] Fix the reproduced blank equipment search viewport with edge-based positioning.
- [x] Verify final scroll-verifier correction and repeated affected journeys (44/44 reports, 5 journeys passed).
- [x] Run focused equipment no-results recovery coverage and isolated handoff (111 package tests, 2 smoke tests, style/docs/boundary/artwork gates passed).
- [ ] Obtain on-device hitch, refresh/thermal/Low Power Mode, and memory evidence.
- [ ] Close and archive only after required evidence is complete; otherwise retain
  a blocked plan with the exact remaining prerequisites.

## Notes

Baseline source: b9b7d6a13c30639aa1b5447909b27184a1727862, with 20 existing dirty
entries in Battle, monetization, and their guidance/tests. Preserve those edits.
Baseline artifacts: `.DerivedData/PerformanceResults/scroll-investigation-baseline`.
Selected Collection, Battle, Homestead groups plus Campaign scroll/party picker,
Spire climb, Contracts browse/refresh/party/return, Battle Log, and salvage return;
two repetitions per scenario. iPhone 14 Pro was paired and initially available; device
profiling is blocked: developer disk image mount failed while locked, then device
connectivity became unavailable. No architectural performance defect established yet.

First pass retained 43 reports; five journeys failed. Four exposed the scroll
verifier's round-trip ambiguity; equipment search rendered a blank result viewport
despite a live "2 of 30 items" count. Adopted edge-based equipment filter scroll
positioning. An intermediate final forward test drag exposed snapping and
subsequent-navigation assumptions; replaced it with a one-way verification
fallback only for ambiguous round trips. The diagnostic pass in
`.DerivedData/PerformanceResults/scroll-investigation-repaired` retained 39/54
reports and two test failures; it includes sampled stacks and is not a clean
timing comparison. The final pass below supersedes those coverage failures.
Host Time Profiler/SwiftUI attachment failed by live PID and by name on Xcode 27;
retain that tooling limitation, rather than claiming an Instruments trace.

Final uninstrumented recheck: `.DerivedData/PerformanceResults/scroll-investigation-final`.
The production change is a correctness fix, not an established frame-rate gain.
The stack samples did not establish material inventory filtering or viewport-map
cost; no speculative caching, container migration, or observation refactor adopted.

## Results and remaining evidence

Final optimized Simulator run: iPhone 17 Pro / iOS 27.0 (iPhone18,1), Xcode
27A266a, Debug with `SWIFT_OPTIMIZATION_LEVEL=-O`, normal artwork/audio enabled.
The 22 selected scenarios each completed twice; observation-mode timing findings
remain. The other 18 scenarios completed twice in the initial baseline. Keep the
sessions separate because source and diagnostic conditions differ.

The equipment regression no longer produces a blank viewport after scrolling
and filtering. Both final search/inspect/equip/unequip repetitions passed;
post-capture screenshots show the two matching cards. No public APIs, saves,
artwork budgets, container choices, or Battle ownership changed.

The inventory sample contained two `InventoryGridView.body` stacks among 16,012
main-thread samples. Shared picker and stage-stack construction also had sparse
samples; XCTest accessibility calls were prominent. This does not prove an
absence of rendering cost, but does not support the proposed model/cache/container
rewrites. Homestead and artwork ownership remain unchanged for the same reason:
no attributable cost or lifecycle defect was established in the available evidence.

Resume on a reachable unlocked iPhone with working developer disk services and
Instruments. Capture Animation Hitches/Time Profiler and SwiftUI update evidence
for equipment filtering, category/detail presentation, Campaign/Spire scrolling,
and Homestead. Record observed refresh cadence, thermal state, Low Power Mode,
and cold/settled/revisit process memory. Only then select further optimizations
or conclude that the remaining callback findings are not shipping regressions.

Focused regression: `HeroDetailAbilityPickerUITests/testHeroDetailItemSearchEquipAndDismiss`
passed after adding a scrolled starting position and no-results recovery. Scoped
FeatureSupport verification passed all 111 package tests. The pre-existing tracked
diff hash matches the baseline after excluding this task's files.

Final handoff passed with `--isolate --smoke` on the six task paths. Both shell
smoke tests passed. No application performance gain is claimed; device hitch,
variable-refresh, thermal/Low Power Mode, and memory verification remain blocked.
