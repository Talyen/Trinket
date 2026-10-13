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

Baseline source: `02489412b9c494a7d117e84d485ee8c179a2b231`.
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
A third full gate is running from the retained build-25 receipt; do not bypass it.

The architecture and five-bug branch patches already exist in main. The dirty
`ios18-runtime` helper visibility change also already exists in main and was left
untouched. Reconciled UI cleanup commit: `02489412b`; newer main-actor wrappers,
iOS 18 guidance, audit behavior, and refund qualification were preserved.

Raw evidence and the findings ledger live in the primary checkout’s explicitly kept
`.DerivedData/PerformanceResults/iphone-performance-1012/` directory. Read the
[performance playbook](../Platform/PerformanceInvestigationPlaybook.md) for evidence
interpretation; callback averages do not prove render-pipeline smoothness.

## Phone preparation and restoration

Wi-Fi only per user. Native Xcode device input rejected the phone; the exclusive
`iphone_operator` subagent successfully used Device Hub Computer Use. TestFlight
still showed installed 0.1.0 (24), not the requested baseline. No game has been
launched for this campaign. Device-wide readiness traces disconnected at about
1.2–1.35 seconds; none qualify as a completed performance capture. Try an
app-specific capture after exact baseline installation, adding Thermal State.

Settings: Low Power Mode off, Limit Frame Rate off, Reduce Motion off. Battery
97% and charging (Slow Charger) at preparation; Maximum Capacity 77%, battery
Service message and dynamic performance-management description. This is a
condition, not an attributed hitch cause. Thermal state remains unknown.
Brightness approximately 45% after temporarily disabling Auto-Brightness.

**Restore at campaign end:** Auto-Brightness on; Auto-Lock 30 seconds (temporarily
Never). Record changes/rechecks in the ledger. Screen sharing is currently stopped;
Device Hub was last selected to the managed StoreKit simulator for a diagnostic
video. Re-select Ryan’s physical phone before any phone input.

Retained deployment: primary checkout `.DerivedData/testflight/20261013T005540Z-25-adc54d`.
Raw evidence ledger/protocol/coverage/run CSV and successful audio video: primary
checkout `.DerivedData/PerformanceResults/iphone-performance-1012/`, explicitly kept.
Both primary and task-worktree TestResults directories have diagnostic keep controls.
No speculative performance or reward fix has been made.
