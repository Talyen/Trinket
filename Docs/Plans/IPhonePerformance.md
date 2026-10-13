---
type: execution-plan
status: active
created: 2026-10-12
updated: 2026-10-12
expires: 2026-10-26
---

# Physical iPhone performance campaign

## Objective

Publish a committed TestFlight baseline, measure real iPhone hitches across equipped
combatant detail and representative gameplay, fix attributed causes, and validate
improvements on an updated TestFlight build. Preserve artwork quality and production
feedback, audio, timing, and cache/pinning contracts.

## Plan

- [x] Audit all registered worktrees; reconcile outstanding UI test cleanup without reverting newer safety fixes.
- [x] Review, run scoped lightweight handoff, integrate through the shared lock, and push main.
- [ ] Complete baseline deployment gate and distribute to Personal Testing.
- [ ] Install and verify the exact TestFlight build on Ryan’s iPhone 14 Pro.
- [ ] Verify native input and Instruments capture; record environment and disposable local save.
- [ ] Measure combatant detail with zero, one, several, and full gear; compare shine-bearing gear.
- [ ] Survey launch/navigation, Collection, combat, outcomes/encounters, maps/Homestead, lifecycle, and 20-minute mixed play.
- [ ] Repeat suspects three times; obtain attribution before fixes and three matched before/after runs.
- [ ] Review and verify fixes, integrate/push, redeploy, and validate TestFlight results.
- [ ] Fold conclusions/blockers into the performance playbook and delete this plan.

## Evidence and constraints

Initial deployment candidate source: `02489412b9c494a7d117e84d485ee8c179a2b231`.
Build 25 has not been archived or uploaded. Record the final clean commit and
exact distributed build before phone measurement; a retained harness change
requires a new build reservation. This investigation has changed no application
code; current main includes separately integrated changes listed below.
Phone: Ryan’s iPhone 14 Pro, UDID `00008120-00024DCC213B401E`, iOS 27.0.1 (24A446).
Live device connection succeeded over local network on October 12.
TestFlight doctor passed for Trinket! / Personal Testing on Xcode 27.1 (27A9275).
The deployment gate must retain iOS 26.2 StoreKit qualification.
A development-signed Release companion from the same source is authorized only
for attribution that TestFlight signing prevents; label its evidence separately.
One device-interaction subagent exclusively owns native captures/input.
No performance finding or improvement is established yet. Baseline version/build
allocated: 0.1.0 (25). Hosted CI passed for the exact baseline source. Two full
local qualification attempts each passed all eight unit suites and 21/22 FullUI
journeys, but failed different reward exits (Labyrinth boss return, then audio
contract return). Focused reruns passed unchanged. A successful-run video and
three temporary Debug claim traces showed completed claims and keyed exit callbacks;
this does not explain the failed runs. Temporary logging was removed completely.
The third full gate failed the first audio contract return again; the task-owned
run was then interrupted, so its cancellation failure is not a separate product
finding. Fresh uninstrumented targeted tests passed both affected journeys
(`ui-20261013T021318Z-22835-30365`). The fourth full gate also failed the
second audio reward return. Fresh DerivedData does not eliminate the blocker.
A focused instrumented failure showed no second
collection/claim entry despite a brief visible button press; stable sampled button
bounds do not support a layout-jump explanation. Later native Music-slider input
also failed (reported 0.75 adjustment, screenshot 0%). A managed graceful simulator
restart did not resolve that slider failure, while Labyrinth passed. No cache,
activation, or input-delivery root cause is established. All temporary application
and test logging was removed. A control restoring the old explicit existence
query passed once and failed once; it was discarded.
Two independent visible-coordinate reward collections returned to Contracts
and awarded gold, including after background/foreground. AX slider setValue
moved the thumb without changing the visible value until a direct drag. These
are automation-input leads, not an established player-facing game defect.
The three paired direct-drag/center-tap runs were 2/0, 2/0 and 1/1; the third
audio journey remained on Victory after its second reward tap. The center-tap
helper and calls were discarded. All three Music drags established backend
starts; retain only that direct gesture with all existing assertions. No reward
fix is established. Raw comparison evidence is in coordinate-input-comparison/.
Current main advanced to 8c2d6e020, including save/progression and combat changes;
incorporate it under the integration lock before final qualification. Do not
bypass or manually mark the deployment gate verified.

The architecture and five-bug branch patches already exist in main. The dirty
`ios18-runtime` helper visibility change also already exists in main and was left
untouched. Reconciled UI cleanup commit: `02489412b`; newer main-actor wrappers,
iOS 18 guidance, audit behavior, and refund qualification were preserved.

Raw evidence and the findings ledger live in the primary checkout’s explicitly kept
`.DerivedData/PerformanceResults/iphone-performance-1012/` directory. Read the
[performance playbook](../Platform/PerformanceInvestigationPlaybook.md) for evidence
interpretation; callback averages do not prove render-pipeline smoothness.

## Pinned release recovery

The task checkout was updated through the shared integration lock to 8a8edc94d
and pushed. Deploy from this isolated checkout so primary main may advance
without changing release inputs. Canonical setup and doctor passed there.
Build 26 at 2c804a1f5 was interrupted before archive/upload when primary main
advanced during verification; this is not a product assertion failure. Original
receipts remain in primary, with copies preserving reservations in this checkout.

Build 27 at 8a8edc94d was interrupted before archive/upload after hosted CI
confirmed an incorrect lingering-Burn test expectation. Burn 6 halves before its
tick, leaving a 100-Health enemy at 97; the test expected 96. Correct only that
expectation and retain every alive/dead-source reward assertion. Raw hosted
artifacts are retained as ci-7c9-engine/ and ci-8a8-engine/. Native Engine
verification passed all 921 discovered tests with the correction. New clean-commit
hosted CI and the complete deployment gate remain required.
No performance fix or phone gameplay result is established.

## Phone preparation and restoration

Wi-Fi only per user. Native Xcode device input rejected the phone; the exclusive
`iphone_operator` subagent successfully used Device Hub Computer Use. TestFlight
still showed installed 0.1.0 (24), not the requested baseline. No game has been
launched for this campaign. Initial device-wide readiness traces disconnected
at about 1.2–1.35 seconds;
one other attempt was invalidated by an interrupted save. A later awake-phone
Animation Hitches + Thermal State capture completed 4.394802s with end reason
Time limit reached and Nominal thermal state throughout. This validates one
Wi-Fi transport attempt only. Try an app-specific capture after exact baseline
installation and recheck thermal state during gameplay.

Settings: Low Power Mode off, Limit Frame Rate off, Reduce Motion off. Battery
97% and charging (Slow Charger) at preparation; Maximum Capacity 77%, battery
Service message and dynamic performance-management description. This is a
condition, not an attributed hitch cause. Thermal state was Nominal during
the successful readiness trace; gameplay thermal state remains unmeasured.
Brightness approximately 45% after temporarily disabling Auto-Brightness.

Use a freshly unique named save without `-reset-state` on the physical phone;
that flag also clears global Options defaults. Seed only the first launch,
disable cloud sync, and record/restore any changed audio, haptic, or auto-battle
preferences. A fresh named save needs no reset.

**Restore at campaign end:** Auto-Brightness on; Auto-Lock 30 seconds (temporarily
Never). Record changes/rechecks in the ledger. Screen sharing is currently stopped;
Device Hub was last selected to the managed StoreKit simulator for a diagnostic
video. Re-select Ryan’s physical phone before any phone input.

Retained deployment: primary checkout `.DerivedData/testflight/20261013T005540Z-25-adc54d`.
Raw evidence ledger/protocol/coverage/run CSV and successful audio video: primary
checkout `.DerivedData/PerformanceResults/iphone-performance-1012/`, explicitly kept.
Both primary and task-worktree TestResults directories have diagnostic keep controls.
No speculative performance or reward fix has been made.
