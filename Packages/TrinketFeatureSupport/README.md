# TrinketFeatureSupport

Shared, game-specific presentation support used by Battle and the non-Battle app
features.

## Products and ownership

| Product | Ownership | Allowed dependencies |
|---|---|---|
| `TrinketFeatureContracts` | SwiftUI-free navigation, deep-link, user-message, and battle presentation/reward values | Core, Content |
| `TrinketFeatureSupport` | Reusable cards/detail panes, encounter and reward UI, presentation models, `AccessibilityID`, prepared artwork, frame analysis | Core, Content, DesignSystem |
| `TrinketFeatureAdapters` | Save-backed map/detail adapters and equipment editing | Support/Contracts plus Core, Content, BattleEngine, Persistence, DesignSystem |

None of these products may import `TrinketBattleFeature`, `TrinketAppState`, or the
app module. Keep app routing, encounter orchestration, and combat lifecycle outside
this package. Adapters submit save commands to Persistence, which owns transactions
and durable storage.

Within `Sources/TrinketFeatureSupport/Shared/`, `Cards/` owns reusable cards and
item artwork, `Encounters/` owns encounter tiles and reading presentation, and
`Rewards/` owns the reward reveal sequence and its views. Victory and Mystery
reveal loot and the primary action together while XP animates, keeping layout
positions stable. Collection becomes available after the reveal fade, independent
of XP completion. A successful claim triggers a brief stationary pulse before
exit; animation never determines the amount awarded. Interrupted collection
finishes the already committed action once.

## Artwork and rendering

`PreparedArtworkCache` decodes off the main actor; publication and pin ownership
stay on the main actor. A cache-owned scheduler admits at most two decodes across
all callers and at most one deferred decode, prioritizing imminent pins over
viewport requests over deferred catalog work. Queued shared jobs inherit their
most urgent caller. Overlapping requests share cache-owned work: cancellation
stops a caller's queued work, while started decodes finish for all consumers.
Pins live outside the evictable `NSCache` cost limit. `PreparedArtworkLease` balances a preparation acquisition over its owner's lifetime;
category navigation acquires it before pushing. Shared artwork-prepared sheet and
navigation modifiers also acquire a lease before exposing item/ability/combatant
details, retaining the source during preparation and the pins through the visit. `ArtworkViewportPrewarm`
owns scroll-driven prefetch. Launch retention follows
[UI performance](../../Docs/AgentContext/ui-performance.md); memory budgets follow
the [performance playbook](../../Docs/Platform/PerformanceInvestigationPlaybook.md).

`HeroHeaderLayout` and `DetailHeroScrollShell` share full-bleed 4:3 detail heroes,
overscroll, and scrim blending. One geometry source drives header height and
pinned-title opacity. `DetailTraitRow` and `DetailHeroHeader` accept optional
`DetailChangeIndicator` values for inline icons with explicit accessible meanings;
features own the mapping from gameplay outcomes to those indicators.

`Shine` owns text and border palettes; `ItemCard` falls back to rarity/Astral
when no override is supplied. `displayTextShine` derives title colors
from displayed affixes, preferring base affinities; Unique titles use gold.
Title palettes do not limit border or plasma keywords. Text delegates to
DesignSystem's `trinketShineText(colors:)`; source owns palette and motion tuning.
Apply `shineText` before fixed foreground fallbacks, including `trinketOnArtText`.
Animated borders rasterize the static gradient before rotation and then mask it
to the card outline. Keep the changing angle outside the drawing group to reuse
the raster instead of redrawing an offscreen surface each frame. Selected product
cards draw a 3-point outline above the shine so selection remains distinct on
Astral and corrupted gear.

## Frame diagnostics

`FramePacingAnalyzer` and `FramePacingSignpostSupport` measure delivered display-link
callbacks, not rendered frames or authoritative hitches. Interpretation follows
the [performance playbook](../../Docs/Platform/PerformanceInvestigationPlaybook.md#signals).
`FramePacingReport` retains tolerant decoding and the UI-test transport's supported
schema compatibility.

`FramePacingMeasurementTiming` owns sampler preparation timing; it never shortens
production animations. `FramePacingMeasurementControl` connects the app probe and
Battle harness without an upward package dependency. Interaction capture begins
after readiness and finishes explicitly after the measured action and its visible
tail. Schema 6 adds monotonic start/end boundaries and completion status; older
reports remain readable but cannot establish complete interaction coverage.
`sampledDuration` describes delivered intervals, while `measurementDuration`
describes the entire capture window. The performance runner owns selection,
coverage validation, and observation/enforcement policy.

## Equipment picker

The slot picker searches item names, base types, displayed affixes, and keyword
names; every search word must match, ignoring case and accents. Its native menu
combines one rarity and one actual affix keyword with the search. Keyword choices
come from all eligible gear, independent of active filters. Clear Filters resets
all three controls. Filtered results show their count against eligible gear.

Each visit starts with equipped gear first, then Unique, Astral, Basic, and name
(with item identity breaking ties). Inspection preserves ordering, filters, and
scroll position; changing filters returns to the top. Successfully equipping closes
the picker. The currently equipped item's detail offers Unequip, which also closes
the picker after a successful save. Failed edits preserve the detail for retry.
Combatant details receive read-only loadouts and result-returning edit commands;
save results control success feedback and navigation, never binding readback.
Initial eligible thumbnails are prepared and pinned before navigation, owned by
the picker visit; the lazy grid prewarms nearby artwork as results and visibility
change. Existing detail and launch pins remain independent.
Item inspection prepares its artwork, ends the active native search interaction,
and waits for `isSearching` to acknowledge dismissal before pushing the detail.
The logical filter query survives native search dismissal and is restored on Back.
This keeps rapid search/inspect/back/equip sequences on the owning navigation stack.
The requested slot highlights immediately and shows progress only when preparation
outlasts the shared pending-indicator delay. A successful equipment edit highlights
its changed slots when the detail becomes visible again; failed saves preserve the
current picker and produce no success accent.
The combatant detail owns that successful return. Nested item details must not
issue a second pop that briefly exposes the intermediate picker.

## Testing

```sh
./Scripts/test-package.sh TrinketFeatureSupport
```

Keep presentation-model, cache, and frame-analysis tests here. Shipping journeys stay
with the closest UI smoke owner.
