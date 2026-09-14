---
type: execution-plan
status: active
created: 2026-09-13
updated: 2026-09-13
expires: 2026-09-27
---

# ArtworkPreparationHitches

## Objective

Keep launch and later artwork/effects responsive through shared bounded decoding,
resource-before-render ordering, off-main raster warmup, and retained imminent art.
Preserve visuals, continuous battle input, existing memory budgets, and save data.

## Plan

- [x] Inspect shared cache, cast/texture warmup, feedback rasterization, battle retention, and navigation owners.
- [x] Implement cache-wide two-decode admission with one deferred slot, priority promotion, deduplication, and cancellation.
- [x] Stage launch layout/rendering and all cast prewarm consumers behind resource readiness.
- [x] Move closed-vocabulary raster composition off the main actor.
- [x] Retain reachable battle artwork and repair first-presentation acquisition gaps; park hidden decorative clocks.
- [x] Add or extend only consequential coverage.
- [ ] Run path-scoped verification for the union of requested and adopted changes.
- [ ] Record the outcome in `Docs/Plans/Archived/README.md`, delete this file, and report verification.

## Notes

Baseline single-run matrix: `.DerivedData/PerformanceResults/20260913T200720Z`.
Compiled baseline app retained in `.DerivedData/ArtworkHitchBaseline/Trinket.app`.
Unrelated existing edits: UI-test README, SmokeBattleTests, TrinketUITestCase.
Physical iPhone 14 Pro is paired; device traces remain required for hitch claims.

Current source/package/style checks pass; app build passed. Smoke is running.
Latest package counts: FeatureSupport 89, BattleFeature 116, DesignSystem 14.
Physical baseline built with Debug plus Swift -O from a read-only archived HEAD
snapshot under `.DerivedData/ArtworkHitchBaseline/source` (no checkout switching).
Remaining: battle overlay construction gate, visual/first-use verification,
formal repeated performance matrix, physical launch traces, final handoff.

Final implementation also gates battle overlay construction and shared nested
item/ability navigation and battle detail sheets before resource publication.
Last full handoff passed five smoke tests; newest shared presentation helper is
in its final scoped handoff. Physical baseline Instruments attempt timed out
waiting for device boot; requested that the user unlock the paired iPhone.

Visual launch recording retained at `.DerivedData/ArtworkHitchAfter/launch.mp4`:
native bar advanced steadily in 15 Hz samples, filled at 3.333 s recording time,
then stayed full until reveal around 4.1 s. Kept the native bar.
Slow-preparation Shop smoke passed. Nested picker UI exposed orphaned item-detail
navigation after Equip when registration was inside the new generic presentation
wrapper. Refactored preparation into a binding/task modifier so the existing
native navigation registrations and parent-owned dismissal remain in place;
focused picker retry is running.
Memory diagnostics exceeded advisory resident/process targets after deferred
warmup in both original and modified Simulator builds; configured caps unchanged.

Picker failure persisted after restoring native registration. Running the exact
picker journey against untouched archived HEAD to classify the issue before
further fixes. The shared navigation helper now owns preparation bindings only;
sheet pins remain retained through native onDismiss.

Untouched baseline picker stopped earlier on the old two-second UI readiness helper.
For a comparable retry, the baseline app remains untouched while its test harness
uses the same pre-existing user-authored readiness-helper changes as this checkout.
Also found normal battle teardown clearing shared immutable glyph/texture caches:
retaining those through normal teardown, preserving explicit memory-pressure trim,
and isolating cancelled texture warmups to a retired cache generation.

Matched baseline picker reproduces the same missing Weapon item slot after Equip
(HeroDetailAbilityPickerUITests line 55); this is pre-existing, not established as
a regression. User reported bar still hitching while baseline was installed.
Restored the latest build and refocused on full-rate launch recording. Original
modified-build video sampled at 60 Hz shows no repeated fill widths in the middle
1.75 seconds (increments mostly 6 px, occasional 3/9 px), but new full-rate capture
is underway before claiming the user's observation resolved.

User confirmed the latest linked video and current Agent Simulator look smooth.
Keeping the native timed progress bar; reverted an unverified TimelineView trial.
Picker readiness waits did not resolve the failure and were reverted. The complete
fix moves selected equipment-item navigation state to CombatantDetailPane, which
now clears the item and slot together on successful equip/unequip. Original picker
assertions/taps remain unchanged; focused verification is running.

Read-only inspection of the failed test's named SQLite store confirmed that the
Astral Longsword was equipped successfully. Native item/slot dismissal bindings
still left the item detail on screen, even after centralizing their state.
Replaced equipment navigation with one value path in CombatantDetailNavigationStack,
updated every current combatant-detail host, and kept the original UI test intact.
This removes both equipment destinations atomically after a successful save.

User confirmed the automated search/reopen failure is real and requested continuing
with a bounded fix. Removed unproven equipment path/state ownership rewrites.
LLDB confirmed saved=true and selectedItemSlot changes weapon->nil while the detail
remains onscreen. User suggested search as the trigger. Testing explicit search
presentation dismissal on successful equip/unequip before parent dismissal, with
search/filter state preserved during ordinary inspection/back and failed saves.

Search investigation: ending search and immediately pushing still lost navigation.
Now preparing the item first, asking a descendant of searchable to dismissSearch,
and opening the detail only after its isSearching environment acknowledges false.
Logical filter query is retained separately from the native search field so Back
restores the query. No arbitrary delays or relaxed test assertions were added.

The original full HeroDetailAbilityPickerUITests journey passed at
ui-20260913T220639Z-4382-21560 (1 passed, 0 failed). This is automated reproduction,
not a manually reproduced general equip failure; clarified that to the user.
Removed the unnecessary save/onFinished callback split after the passing search
lifecycle fix; original parent-owned equip/unequip dismissal is retained.
Remaining verification: repeat that unchanged journey after cleanup, full scoped
handoff, five-repetition performance run, optional device traces if available.

Confirmation after cleanup passed unchanged at ui-20260913T221311Z-10172-15378
(1 passed, 0 failed). Latest code keeps original equipment save/navigation callbacks.
Final scoped handoff followed by the prescribed five-repetition performance pass
is running in the held Agent 1 lease. No further feature changes are planned.
