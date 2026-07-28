# TrinketFeatureSupport

Shared, game-specific presentation support used by Battle and the non-Battle app
features.

## Ownership

- Reusable cards, detail panes, encounter/reward components, and resource views
- Journey, stage, labyrinth, homestead, and combatant presentation models
- `AccessibilityID`, prepared artwork, and frame-pacing analysis contracts

This package may depend on the lower-level domain, content, engine, persistence, and
design-system packages. It must not import or depend on `TrinketBattleFeature`,
`TrinketAppState`, or the app module. Shared detail presentation is allowed to use
read-only `BattleEngine` build/resolution types; combat lifecycle and mutation remain
outside this package.

## Testing

```sh
./Scripts/test-package.sh TrinketFeatureSupport
```

Keep presentation-model, cache, and frame-analysis tests here. Shipping journeys stay
with the closest UI smoke owner.
