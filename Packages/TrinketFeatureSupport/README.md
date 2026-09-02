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

- **Artwork Cache & Warmup**: `PreparedArtworkCache` manages decoded UI bitmaps. Priority assets decode during launch before releasing the interactive UI and stay pinned to avoid hitching on presentation frames; remaining catalog items decode deferred at utility priority. `ArtworkViewportPrewarm` debounces scroll-driven prefetch windows (forward/backward rows). Pinned pictures live outside the evictable `NSCache` cost limit, so the evictable cap (160–260 MiB by device memory) always sits below the total resident warning level (320 MiB); process steady-state target is 550 MiB. Memory targets and enforcement belong to the [performance playbook](../../Docs/Platform/PerformanceInvestigationPlaybook.md).
- **Detail Hero Presentation**: `HeroHeaderLayout` and `DetailHeroScrollShell` standardize full-bleed detail sheets (combatants, abilities, items) across the app, ensuring consistent aspect ratio scaling (`4:3`), rubber-band overscroll metrics, and gradient scrim blending into canvas backgrounds. Single geometry source in `DetailHeroScrollShell` drives both header height and pinned-title opacity.
- **Shine System**: `Shine` is the single source for text and border shimmer (keyword, color, unique, corruption). Views take `Shine` directly (`shineText(_:)`, `shineBorder(_:)`); `ItemCard` falls back to rarity/astral when no override is passed. `InventoryItem.astralShine` is the single model derivation.
- **Frame Pacing Diagnostics**: `FramePacingAnalyzer` and `FramePacingIntervalModifier` provide signpost instrumentation and refresh-normalized interval analytics for render delivery, stalls, and 1% low framerate. `FramePacingReport` is `Codable` with tolerant decoding (unknown future fields ignored, missing keys default); the UI-test transport preserves its supported schema compatibility.

## Testing

```sh
./Scripts/test-package.sh TrinketFeatureSupport
```

Keep presentation-model, cache, and frame-analysis tests here. Shipping journeys stay
with the closest UI smoke owner.
