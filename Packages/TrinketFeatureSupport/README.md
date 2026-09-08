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
app module. Keep app routing, encounter orchestration, combat lifecycle, and save
mutations outside this package.

Within `Sources/TrinketFeatureSupport/Shared/`, `Cards/` owns reusable cards and
item artwork, `Encounters/` owns encounter tiles and reading presentation, and
`Rewards/` owns the reward reveal sequence and its views.

## Architecture and Core Systems

- **Artwork Cache & Warmup**: `PreparedArtworkCache` manages decoded UI bitmaps. Image loading and decoding run off the main actor; cache publication and pin ownership remain on the main actor. Priority assets decode during launch before releasing the interactive UI and stay pinned to avoid hitching on presentation frames; remaining catalog items decode deferred at utility priority. `ArtworkViewportPrewarm` debounces scroll-driven prefetch windows (forward/backward rows). Pinned pictures live outside the evictable `NSCache` cost limit. Current memory targets and enforcement belong to the [performance playbook](../../Docs/Platform/PerformanceInvestigationPlaybook.md).
- **Detail Hero Presentation**: `HeroHeaderLayout` and `DetailHeroScrollShell` standardize full-bleed detail sheets (combatants, abilities, items) across the app, ensuring consistent aspect ratio scaling (`4:3`), rubber-band overscroll metrics, and gradient scrim blending into canvas backgrounds. Single geometry source in `DetailHeroScrollShell` drives both header height and pinned-title opacity.
- **Shine System**: `Shine` is the single source for text and border shimmer (keyword, color, unique, corruption). Views take `Shine` directly (`shineText(_:)`, `shineBorder(_:)`); `ItemCard` falls back to rarity/astral when no override is passed. `InventoryItem.displayShine` derives the border palette. `displayTextShine` uses up to three keywords from displayed affix descriptions, preferring matching base affinities, with primary and 55%-opacity color pairs. Unique titles use gold pairs; title palettes do not limit border or plasma keywords. Animated border strokes use an offscreen drawing group to avoid repeated CPU rasterization of angular gradients. Apply `shineText` before fixed foreground fallback modifiers, including `trinketOnArtText`, so the gradient takes precedence.
- **Frame Pacing Diagnostics**: `FramePacingAnalyzer` and `FramePacingSignpostSupport` provide signpost instrumentation and refresh-normalized interval analytics for render delivery, stalls, and 1% low framerate. `FramePacingReport` is `Codable` with tolerant decoding (unknown future fields ignored, missing keys default); the UI-test transport preserves its supported schema compatibility.

## Equipment picker

The slot picker searches item names, base types, displayed affixes, and keyword
names; every search word must match, ignoring case and accents. Its native menu
combines one rarity and one actual affix keyword with the search. Keyword choices
come from all eligible gear, independent of active filters. Clear Filters resets
all three controls. Filtered results show their count against eligible gear.

Each visit starts with equipped gear first, then Unique, Astral, Basic, and name
(with item identity breaking ties). Inspection preserves ordering, filters, and
scroll position; changing filters returns to the top. Equipping closes the picker.
Initial eligible thumbnails are prepared and pinned before navigation, owned by
the picker visit; the lazy grid prewarms nearby artwork as results and visibility
change. Existing detail and launch pins remain independent.

## Testing

```sh
./Scripts/test-package.sh TrinketFeatureSupport
```

Keep presentation-model, cache, and frame-analysis tests here. Shipping journeys stay
with the closest UI smoke owner.
