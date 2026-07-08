# TrinketDesignSystem

Shared app chrome — semantic surfaces, typography, keyword visuals, and reusable components. Depends on `TrinketCore` only (no `BattleEngine` or `TrinketContent`).

## Components

| File | Role |
|------|------|
| `TrinketDesign.swift` | Appearance modes, colors, metrics, and card chrome |
| `VisualFoundation.swift` | Background modes, surface roles, spacing tokens |
| `Keyword+VisualStyle.swift` | Color + SF Symbol per Keyword |
| `Modifiers.swift` | Semantic view modifiers for backgrounds, surfaces |
| `ExperienceBar.swift` | XP/level progress bar |
| `HomesteadTint+Color.swift` | Homestead node tint resolution |

## Appearance

App chrome uses Apple semantic system colors through `ThemePalette.apple`. Players choose **System**, **Light**, or **Dark** appearance via `OptionsStore.appearance` in Options. Tests can override with the `-appearance` launch argument.

## Surface roles

Use semantic modifiers (`.trinketSurface(.base)`, `.trinketScreenBackground(.playJourney)`) instead of hardcoded colors. Roles include `base`, `secondary`, `elevated`, `card`, `denseRow`, `selected`, `disabled`, `warning`, `reward`, `modal`, `popover`.

## Keyword styling

Every keyword has one visual identity via `Keyword.visualStyle`. Do not introduce one-off keyword colors in feature views.

See `Docs/Design/StyleGuide/AppVisualFoundation.md` for the full visual direction.
