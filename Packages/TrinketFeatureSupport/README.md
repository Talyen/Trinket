# TrinketFeatureSupport

Shared, game-specific presentation support used by Battle and the non-Battle app
features.

## Products and ownership

| Product | Ownership | Allowed dependencies |
|---|---|---|
| `TrinketFeatureContracts` | SwiftUI-free navigation, messages, battle lifecycle interfaces, and presentation/reward values | Core, Content, BattleEngine |
| `TrinketFeatureSupport` | Reusable cards/detail panes, encounter and reward UI, presentation models, `AccessibilityID`, prepared artwork, frame analysis | Core, Content, DesignSystem |
| `TrinketFeatureAdapters` | Save-backed map/detail adapters and equipment editing | Support/Contracts plus Core, Content, Persistence, DesignSystem |

None of these products may import `TrinketBattleFeature`, `TrinketAppState`, or the
app module. Keep app routing, encounter orchestration, and combat lifecycle implementation outside
this package. Adapters submit save commands to Persistence, which owns transactions
and durable storage.

Within `Sources/TrinketFeatureSupport/Shared/`, `Cards/` owns reusable cards and
item artwork, `Encounters/` owns encounter tiles and reading presentation, and
`Rewards/` owns the reward reveal sequence and its views. Victory and Mystery
reveal loot and the primary action together while XP animates, keeping layout
positions stable. Pinned reward actions clip the scroll viewport above their footer
so partially scrolled labels are not blurred or dimmed beneath it.
`RewardRevealShell` keeps rewards top-aligned through reveal and
viewport changes so the heading remains reachable, and automatically pins actions in short or wide
viewports; its inline-height threshold scales with native body text. Victory,
defeat and recruitment share that policy, while an explicit pinning argument can
override it. Taller windows retain the inline action. Collection becomes available after the reveal fade, independent
of XP completion. A successful claim triggers a brief stationary pulse before
exit; animation never determines the amount awarded. Interrupted collection
finishes the already committed action once. Astral and Unique items receive a
brief scale settle and a single exceptional-loot cue when first focused. The
reward presentation owns item-ID deduplication across paging and inspection;
collection cancels remaining decoration. Backgrounding and disappearance consume
only the focused item’s pending cue, allowing later unseen pages to flourish. Playback is supplied by the consuming feature so live Effects volume remains
with the existing audio owner. Basic items and wallet reveal timing are unchanged.

`HomesteadProjectStatus` and `HomesteadCategoryProgress` are save-free presentation
models using Content state and Gold values. `HomesteadResourceWallet` also takes
these values directly, keeping shared Homestead UI independent of Persistence.

`Artwork/` owns prepared-artwork caching and leases, `Performance/` owns frame
measurement, and `Accessibility/` owns stable accessibility identifiers. These
folders remain in the `TrinketFeatureSupport` target.

## Artwork and rendering

Item cards use `ItemCardLabel` for the rarity/status and name stack: bold caption
eyebrows above medium subheadline names, with 2-point internal spacing. Card
labels have 4-point horizontal padding and sit 8 points below artwork, with any
reserved label height extending below the text rather than above it; item-grid
rows leave 16 points after their tallest label. Empty equipment slots use the same
name role and secondary color. Corruption status shares the rarity's eyebrow role
and moves below it when the pair cannot fit horizontally. Reward reveals use the
larger `sectionDisplay` name role; on-art details use `screenDisplay`. Both retain
the same `displayTextShine` title palette as inventory cards.

`PreparedArtworkCache` decodes off the main actor; publication and pin ownership
stay on the main actor. A cache-owned scheduler admits at most two decodes across
all callers and at most one deferred decode, prioritizing imminent pins over
viewport requests over deferred catalog work. Queued shared jobs inherit their
most urgent caller. Overlapping requests share cache-owned work: cancellation
detaches a caller and releases its pin demand immediately, while started decodes
keep their admission slots and finish for surviving consumers and the cache.
Pins live outside the evictable `NSCache` cost limit. `PreparedArtworkPinSet` owns
replaceable surface working sets: only the latest preparation can publish pins,
release invalidates pending acquisitions, and transition completion tokens prevent
obsolete fades from releasing newer artwork. Screens retain outgoing pins through
their own transition timing, then finish the matching update. `PreparedArtworkLease`
balances a fixed acquisition over its owner's lifetime or explicit idempotent release.
Raw acquisition/release-by-name operations stay internal to this target. Launch
replacement transfers a lease once and releases abandoned preparation automatically;
category navigation acquires it before pushing. Shared artwork-prepared sheet and
navigation modifiers also acquire a lease before exposing item/ability/combatant
details, retaining the source during preparation and the pins through the visit. `ArtworkViewportPrewarm`
owns scroll-driven prefetch. Launch retention follows
[UI performance](../../Docs/AgentContext/ui-performance.md); memory budgets follow
the [performance playbook](../../Docs/Platform/PerformanceInvestigationPlaybook.md).

`HeroHeaderLayout` and `DetailHeroScrollShell` share full-bleed detail heroes,
overscroll, and scrim blending. Portrait, square, cinematic and talent-tree headers are bounded
by usable viewport height so their summaries and following content remain visible.
The shell’s scroll geometry drives header height,
pinned-title opacity, and artwork overscroll zoom even after the hero scrolls
offscreen. Overscroll is supplied only to the header subtree. Artwork extension
follows cropping, blending and overscroll transforms, without an outer clip; title
and footer remain safe-area foreground. Hero combatant artwork uses the upper
portrait crop when wide headers cannot show its full height; card and battle crops
are unchanged. Follow [content beside native bars](../../Docs/Platform/ApplePlatformReference.md#content-beside-native-bars)
for all shared grids, shelves and detail consumers. `DetailTraitRow` and
`DetailHeroHeader` accept optional `DetailChangeIndicator` values for inline icons
with explicit accessible meanings; features own the mapping from gameplay outcomes
to those indicators.

`Shine` owns text and border palettes; `ItemCard` falls back to rarity/Astral
when no override is supplied. `displayTextShine` derives title colors
from displayed affixes, preferring base affinities; Unique titles and their
signature trait use gold, while supporting traits use keyword shine.
Title palettes do not limit border or plasma keywords. Text delegates to
DesignSystem's `trinketShineText(colors:)`; source owns palette and motion tuning.
Apply `shineText` before fixed foreground fallbacks, including `trinketOnArtText`.
Artwork clips at the composed card tile's bounds, shared by its border overlays.
Animated borders stroke the angular gradient directly into the inset card outline;
the changing angle rotates the color sweep while the outline stays fixed. Selected product
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
the picker. Compact, icon-only equipment badges use a checkmark for the combatant
being edited and a person for another wearer. Accessibility labels name the other
wearer; the detail action says “Move from [name]” before transferring the item.
Ownership comes from the live roster so the badge follows saved loadout changes.
The picker indexes item wearers once per equipment-loadout change, sharing the
lookup between badges and detail actions without scanning the roster per row.
The currently equipped item's detail offers Unequip, which also closes
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

Package execution and local diagnostic opt-in follow
[Verification](../../Docs/Platform/Verification.md#execution-limits); routine local
changes use path-scoped handoff.

```sh
./Scripts/test-package.sh TrinketFeatureSupport
```

Keep presentation-model, cache, and frame-analysis tests here. Shipping journeys stay
with the closest UI smoke owner.
