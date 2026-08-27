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

## Architecture and Core Systems

- **Artwork Cache & Warmup**: `PreparedArtworkCache` manages decoded UI bitmaps. Priority assets decode during launch before releasing the interactive UI and stay pinned to avoid hitching on presentation frames; remaining catalog items decode deferred at utility priority within resident memory budgets (`240 MiB` resident artwork target).
- **Detail Hero Presentation**: `HeroHeaderLayout` and `DetailHeroScrollShell` standardize full-bleed detail sheets (combatants, abilities, items) across the app, ensuring consistent aspect ratio scaling (`4:3`), rubber-band overscroll metrics, and gradient scrim blending into canvas backgrounds.
- **Frame Pacing Diagnostics**: `FramePacingAnalyzer` and `FramePacingIntervalModifier` provide signpost instrumentation and refresh-normalized interval analytics to evaluate 60/120 Hz render delivery, stall ratios, and 1% low framerate metrics.

## Testing

```sh
./Scripts/test-package.sh TrinketFeatureSupport
```

Keep presentation-model, cache, and frame-analysis tests here. Shipping journeys stay
with the closest UI smoke owner.
