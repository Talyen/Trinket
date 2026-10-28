---
type: execution-plan
status: active
created: 2026-10-12
updated: 2026-10-25
expires: 2026-10-26
---

# Physical iPhone performance campaign

## Objective and boundaries

Establish a committed TestFlight baseline, measure attributed device hitches, and
validate fixes on an updated beta. Preserve artwork, feedback, sound, timing and
pinning. The original task authorized integration, push, deployment and a
same-source development-signed Release companion only where profiling requires it.
Use Wi-Fi only, and one device operator for captures/input.

## Recorded status and blockers

This campaign has not established its requested TestFlight baseline or gameplay
performance result. Its last observed installation was **0.1.0 (24)**. Builds
25–30 encountered qualification failures or interruption; do not bypass the gate
or infer deployment from a build reservation. The latest recovery at `83cb9ab23`
repaired private receipt-wrapper and test compilation. Engine, Persistence and
AppState tests passed locally (the unrequested playthrough worker was skipped);
new exact-commit hosted and deployment checks remain required.

Intermittent reward-return failures remain unexplained despite focused passes and
fresh build output. Music-slider accessibility input changed the thumb without
the displayed value; direct drags established playback. These are automation
leads, not proven player defects. Preserve reward assertions and the direct Music
gesture; discarded tap/query prototypes and temporary logging remain removed.

### Later recorded investigations

These observations were moved from the standing performance playbook during the
October 25 documentation review; no device or installed build was rechecked.
Reconcile them with release receipts before resuming the campaign.

Direct-launch, app-scoped CPU and Animation Hitches capture has worked over Wi-Fi;
attachment and device-wide capture remain unreliable. Launch, scrolling, Campaign
transitions and card play have recorded hitches. Their remaining causes and
shipping-device improvements need controlled attribution and matched measurements.

The October 19 iPhone 14 Pro captures include completed, symbol-matched CPU and
frame recordings, including the retained `iphone-wifi-survey-20261019/homestead-after`
and `homestead-normal-after` results. Their `result.json` files report passed capture
and matching app symbols; they identify the installed build as 0.1.0 (6), but do not
verify its optimization configuration. These are completed physical-device captures,
not proof of the separate TestFlight baseline, current-source memory attribution,
or a performance improvement.

Existing optimizations reduce recurring Stun rendering and compositor work, and
spread hidden-root layout. Their evidence does not establish hitch elimination, a global
FPS floor, lower total launch CPU, or faster readiness. Retain native navigation,
sheet motion, artwork budgets and pinning. Full-card warmup and removal of Combat
Log navigation chrome did not justify adoption. SwiftUI attribution instrumentation
added symbol-lookup overhead, so its gesture timings are not production measurements.

Thermal/Low Power Mode, cold/settled/revisit memory, background/foreground and
direct-touch dismissal evidence remain open. Controlled refresh-cadence, first-use
artwork, equipment/shared browsing, save/reward returns and rapid-combat checks
also remain incomplete. Resume under the
[investigation loop](../Platform/PerformanceInvestigationPlaybook.md#investigation-loop)
when a player-visible problem is reproducible or tools permit the missing checks.
Closed investigations do not waive these gaps or justify visual reductions.

Detailed measurements and rejected experiments remain in Git history and retained
profiles under `~/Library/Developer/Trinket/BuildArtifacts/profiles/`, especially
`iphone-investigation-20261019/` and `iphone-hitches-followup-20261019/`.
Older capture diagnostics used `.DerivedData/PerformanceResults/`. Check artifact
availability and matching binaries/symbols before reuse; historical observations
do not establish today's device, installed build, or tool reliability.

The weekly [real-player soak](../Platform/PlayerCoverage.md) retains diagnostic simulator
footprint/audio observations. It supplies functional ownership and repeated-play
coverage, not hardware budgets or authoritative audible/thermal evidence.

## Remaining work

- [ ] Complete baseline deployment qualification from a clean, isolated revision;
  preserve the qualified StoreKit runtime and existing build-number reservations.
- [ ] Install and verify the exact beta on Ryan's iPhone 14 Pro
  (`00008120-00024DCC213B401E`); refresh device/OS, input, thermal and recording evidence.
- [ ] Measure combatant detail with zero, one, several and full gear, including
  shine-bearing equipment. Survey launch, navigation, Collection, combat,
  outcomes/encounters, maps/Homestead, lifecycle and 20-minute mixed play.
- [ ] Repeat suspects three times, obtain attribution before editing, and collect
  three matched before/after runs. Label development and TestFlight evidence separately.
- [ ] Review, verify, integrate/push, redeploy and validate any confirmed fixes;
  restore changed phone settings, fold reusable requirements into the playbook,
  preserve results in the handoff and delete this plan.

## Device safety and restoration

Use a fresh unique named save; seed only its first launch and disable cloud sync.
Do not use `-reset-state` on the phone: it also clears global Options. Record and
restore audio, haptic and Auto Battle preferences.

On October 12, iPhone 14 Pro / iOS 27.0.1 (`24A446`) used Xcode 27.1 (`27A9275`).
Low Power Mode, Limit Frame Rate and Reduce Motion were off. Auto-Brightness was
temporarily disabled and Auto-Lock set to Never. **Restore Auto-Brightness on and
Auto-Lock to 30 seconds at campaign end.** Recheck current settings before changing
them. The observed battery Service condition is not an attributed hitch cause;
thermal state requires a fresh trace. Screen sharing was stopped; reconfirm the
target device before input.

## Evidence pointers

The primary checkout retained deployment
`.DerivedData/testflight/20261013T005540Z-25-adc54d` and explicitly kept
`.DerivedData/PerformanceResults/iphone-performance-1012/` with its ledger,
protocol, coverage CSV, traces and successful audio video. Comparison/probe
subdirectories include `coordinate-input-comparison/`, `hand-membership-failure/`,
`hand-membership-verification/`, `retry-watchdog-verification/`, `ci-83cb-build/`
and `ci-83cb-engine/`. Confirm files exist before reuse; the original build-30
receipt and legacy build reservations must survive recovery. Both original
TestResults locations have keep controls.

The [profiling workflow](../Platform/PerformanceInvestigationPlaybook.md#physical-device-profiling-over-wi-fi)
owns recording and interpretation. A partial saved trace, CPU sample, focused test
pass or callback average does not establish rendered-frame improvement. Earlier
build attempts and discarded experiments remain in this file's Git history.
