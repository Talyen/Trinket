---
type: execution-plan
status: blocked
reason: The installed Xcode 27.0 SDK lacks iOS 27.1 Duo APIs; fold implementation and verification require a suitable SDK and runtime.
created: 2026-09-21
updated: 2026-09-21
expires: 2026-10-05
---

# iPhone Duo support

## Objective and approved design

Preserve portrait-only regular iPhone gameplay and the iOS 26 minimum. Flat Duo
screens keep enemy above hero/companion, with the fanned hand underneath. A
horizontal active fold separates battlefield above from hand below; a vertical
fold separates battlefield leading from hand trailing. Width alone must never
switch a flat display to side-by-side combat. Preserve card/artwork proportions,
three-card hand, gameplay, navigation, saves, and prepared artwork lifetimes.

Apple references: [Duo overview](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo),
[design guidance](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo),
and [ArrangementView](https://developer.apple.com/documentation/swiftui/arrangementview).

## Current implementation checkpoint

- Battlefield metrics now accept the actual available battlefield size. The flat
  composition, rather than the combatant grid, owns hand reservation and overlap.
- Manual card origins use the hand's frame in the battle coordinate space.
  Auto Battle reads the latest measured hand frame for each play instead of
  capturing the battle size when its long-running task begins.
- Automatic reveal casts accept an explicit staging frame and hand width.
- A changed hand frame cancels an uncommitted press/drag and its cue. Inspection
  stays held until dismissal; committed cast requests retain their identity/time.
- No fold-specific layout, new public interfaces, engine rules, persistence,
  toolbar changes, or supporting-screen adaptations have been implemented yet.

## Remaining implementation

1. Select an Xcode installation with the iOS 27.1 SDK using DEVELOPER_DIR; do not
   change global xcode-select. Verify public API signatures and runtime availability.
   Use small iOS 27.1 availability gates, preserving the existing older-OS path.
2. Use overlay ArrangementView with hand primary and battlefield secondary,
   outside scrolling content. Give separated battlefield regions their full
   available height. Measure both regions in the shared battle coordinate space.
   Avoid active fold/camera regions for controls, bars, casts, and essential feedback.
   Keep backgrounds full bleed. Bound artwork/card sizes without changing compact
   geometry; preserve live view/session/card identities across layout changes.
3. Update cast staging and in-flight cast positioning against usable regions;
   geometry changes must not replay commands, reset clocks, repeat outcomes, or
   restart Auto Battle. Verify interrupted drags cannot commit on later release.
4. Retain native tabs, stacks, and sheets. Adapt vertical toolbar representations
   using semantic titles/symbols; keep Auto Battle accessible and secondary battle
   actions in native overflow while preserving regular-iPhone appearance.
5. Adapt Campaign, Spires, Contracts, Homestead, Collection, and party-picker grids
   around usable regions, retaining card proportions, reading/selection order,
   current navigation, and prepared artwork. Avoid cards spanning an active fold.
6. Make Labyrinth's existing map/inspector overlay fold-aware and replace its
   fixed clearance with measured occupied space. Preserve node and scroll state.
   Make outcome, Mystery, Shop, onboarding, and detail content reachable at short
   heights, using scrolling and native sheet adaptation. No persistent detail
   panes, landscape enablement, or broader accessibility redesign.
7. Complete verification below, update canonical behavior documentation, archive
   the outcome, and delete this execution plan only when the full work is complete.

## Verification

- Before edits: clean main checkout; Xcode 27.0 (27A266a), only iOS 27.0 SDKs.
  Managed baseline app build passed. Device Hub Computer Use timed out twice;
  interactive battle baseline could not be captured. A Play hub screenshot was
  captured through the managed lease at /tmp/trinket-duo-baseline.png.
- Scoped handoff passed, including style, documentation, cheap CI slices, 168
  BattleFeature package tests, and five SmokeBattleTests. The two existing
  BattleFlowUITests also passed (inspection, tap/drag play, cancelled drags,
  Auto Battle, combatant detail, and retreat). App/test builds succeeded.
  Device: iPhone 17 Pro, iOS 27.0, managed Trinket Agent 1. Final source diff and
  whitespace review passed; no generated changes, commit, or push.
- Evidence: .DerivedData/HandoffResults/handoff.KfyIiH;
  package run TrinketBattleFeature-20260921T025838Z-46289-24043;
  smoke run smoke-20260921T025906Z-46816-5162;
  interaction run ui-20260921T030137Z-48339-24591.
- Required after SDK availability: regular-iPhone before/after visual inspection
  on iOS 26 and newest supported runtime; Duo closed/open/both fold axes and
  multitasking; resize during drag, inspection, Auto Battle, automatic cast,
  outcome reveal, and collection. Verify no accidental/duplicate plays, lost
  selection, dismissed sheets, or restarted battle. Check every core flow for
  clipping, fold intersections, toolbar access, and artwork cropping.
- Record exact runtime/device/build identities. Unit checks and a green build do
  not establish visual parity or Duo usability. Beta evidence does not qualify a
  release; physical checks and unavailable runtimes remain explicit gaps.
