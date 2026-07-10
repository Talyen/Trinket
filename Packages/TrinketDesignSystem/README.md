# TrinketDesignSystem

Shared app chrome — semantic surfaces, typography, keyword visuals, and reusable components. Depends on `TrinketCore` only (no `BattleEngine` or `TrinketContent`).

## Components

| File | Role |
|------|------|
| `TrinketDesign.swift` | Appearance modes, colors, metrics, and card chrome |
| `DesignAssetColors.swift` | Package-bundled semantic color assets (`Bundle.module`) |
| `Resources/DesignColors.xcassets` | Keyword and encounter color sets |
| `VisualFoundation.swift` | Background modes, surface roles, spacing tokens |
| `Keyword+VisualStyle.swift` | Color + SF Symbol per Keyword |
| `Modifiers.swift` | Semantic view modifiers for backgrounds, surfaces |
| `ExperienceBar.swift` | XP/level progress bar |
| `HomesteadTint+Color.swift` | Homestead node tint resolution |

## Appearance

App chrome uses Apple semantic system colors through `ThemePalette.apple`. Default appearance is **Dark**; players can choose **System**, **Light**, or **Dark** via `OptionsStore.appearance` in Options. Tests can override with the `-appearance` launch argument.

## Surface roles

Use semantic modifiers (`.trinketSurface(.base)`, `.trinketScreenBackground(.playJourney)`) instead of hardcoded colors. Roles include `base`, `secondary`, `elevated`, `card`, `denseRow`, `selected`, `disabled`, `warning`, `reward`, `modal`, `popover`.

## Keyword styling

Every keyword has one visual identity via `Keyword.visualStyle`. Do not introduce one-off keyword colors in feature views.

## Modern API Inventory

Route recurring chrome through these modifiers — do not call raw SwiftUI styling APIs from feature views.

| Modifier / API | Use for |
|----------------|---------|
| `.trinketScreenBackground(_:)` | Tab/screen background by semantic `BackgroundMode` |
| `.trinketSurface(_:)` | Panels, cards, rows, selected/disabled/warning/reward states |
| `.trinketMaterial(_:)` | Bottom bars, popovers, reward reveals; modal uses solid surface; toolbar passes through |
| `.trinketGlassChip()` | Glass capsule chips via shared `TrinketGlassBackgroundModifier` |
| `.trinketTypography(_:)` | Scalable text hierarchy (`TypographyRole`) |
| `.trinketCardSurface()` | 3:4 card identity tiles |
| `.trinketLockedCardEffect(isLocked:text:cornerRadius:)` | Subtle desaturation + opaque content blur (blur skipped under Reduce Transparency), larger secondary-grey lock icon in a liquid glass chip |
| `.trinketPrimaryActionButton()` | Primary CTAs (`.glassProminent`) |
| `.trinketStatusBadge()` / `.trinketWalletPill()` | Glass capsule chips with Reduce Transparency solid fallbacks |
| `.trinketSensoryFeedback(_:trigger:enabled:)` | Gate `.sensoryFeedback` on Options haptics toggle |

Glass and material modifiers resolve to solid themed surfaces when **Reduce Transparency** is enabled — this is an accessibility fallback, not older-OS support. Deployment target is iOS 26.0 only.

Platform API notes and deprecated patterns: `Docs/Platform/iOS26AppleReference.md`. Fluid motion: `Docs/AgentMotion.md`. Dense content stays on solid themed surfaces; glass belongs on chrome and selective overlays (`VisualFoundation.swift` surface roles above).
