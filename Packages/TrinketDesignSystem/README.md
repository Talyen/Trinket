# TrinketDesignSystem

Shared app chrome — semantic surfaces, typography, keyword visuals, and reusable components. Depends on `TrinketCore` only (no `BattleEngine` or `TrinketContent`).

## Components

| File | Role |
|------|------|
| `TrinketDesign.swift` | Colors, metrics, overlays, and card chrome |
| `ThemePalette.swift` | Internal mapping from `Theme*` assets to role colors |
| `DesignAssetColors.swift` | Package-bundled semantic color assets (`Bundle.module`) |
| `Resources/DesignColors.xcassets` | Theme, keyword, encounter, placeholder, homestead, resource, chapter color sets |
| `VisualFoundation.swift` | Background modes, surface roles, spacing tokens |
| `HeroScrim.swift` | Hero art scrims and on-art text styling |
| `ArtworkBlend.swift` | Optional semantic perimeter and bottom-edge artwork blending |
| `Keyword+VisualStyle.swift` | Color + SF Symbol per Keyword |
| `HomesteadTint+Color.swift` | Homestead node tint resolution |
| `HomesteadResource+Color.swift` | Homestead resource tint resolution |
| `Modifiers.swift` | Semantic view modifiers for backgrounds, surfaces |
| `ExperienceBar.swift` | XP/level progress bar |
| `VerticalPathRail.swift` | Shared vertical node rail + connectors (Homestead / Stage select); `PathNodeMetrics` + `PathNodeChrome` keep circle size, stroke weight, and glyph scale in sync |

## Color families

All production colors load from `DesignColors.xcassets` through `DesignAssetColors`. Do not invent `Color.green`, raw RGB, or app-bundle `Color("…", bundle: .main)` in feature views.

| Family | Public API | Assets |
|---|---|---|
| Theme chrome | `TrinketDesign.Colors.canvas/surface/panel/…/accent/success/…` | `ThemeCanvas`, `ThemeSurface`, … |
| Gameplay health | `TrinketDesign.Colors.health`, `.healthRestore`, battle derived opacities | `ThemeHealth`, `ThemeHealthRestore` |
| Overlays | `TrinketDesign.Colors.Overlay.ink/paper/heroWarm/…` | `ThemeOverlayInk`, `ThemeOverlayPaper`, `ThemeHeroScrim` |
| Keywords | `Keyword.visualStyle.color` | `KeywordPhysical` … `KeywordDeathsDoor` |
| Encounters | `TrinketDesign.Colors.encounter*` | `EncounterBattle` … |
| Placeholders | `TrinketDesign.CardPlaceholderStyle.*` | `PlaceholderHero` … |
| Homestead tints | `HomesteadTint.color` | `HomesteadTintOrange` … |
| Resources | `HomesteadResource.tint` | `ResourceWood` … `ResourceCrystal` (+ gold via KeywordGold) |
| Chapter | `TrinketDesign.Colors.chapterVerdant` | `ChapterVerdant` |

Hero art overlays use `TrinketHeroScrim.gradient(for:)` and `.trinketOnArtText(_:)`.

**Enforcement:** `./Scripts/check-ui-style.sh` and SwiftLint custom rules fail style/CI on one-off colors. Coding agents also load `.cursor/rules/design-system-colors.mdc` and `AGENTS.md`. Escape hatch: nearby `UIStyleCheck: allow` with a concrete reason. New colors = new `DesignColors` asset + public design-system API.

## Typography

Use `.trinketTypography(_:)` for all readable text. Do not call raw `.font(...)` for copy.

| Role family | Typeface | Use for |
|---|---|---|
| `*Display` (`screenDisplay`, `sectionDisplay`, `rowDisplay`) | Serif (New York) | Branded heroes and journey names on art |
| `*Title` (`screenTitle`, `sectionTitle`, `cardTitle`) | SF Pro | Apple-native UI chrome, lists, shelves |
| `eyebrow` | SF caption bold | Label **above** a hero title (chapter, role, rarity) |
| Body / caption / badge / button / statValue / … | SF Pro | Supporting copy and controls |

Hero stack order is always **eyebrow → title** (never title then rarity/role).

## Surface roles

Use semantic modifiers (`.trinketSurface(.base)`, `.trinketScreenBackground()`) instead of hardcoded colors. Roles include `base`, `secondary`, `elevated`, `card`, `denseRow`, `selected`, `disabled`, `warning`, `reward`, `modal`, `popover`.

## Keyword styling

Every keyword has one visual identity via `Keyword.visualStyle`. Do not introduce one-off keyword colors in feature views.

## Modern API Inventory

Route recurring chrome through these modifiers — do not call raw SwiftUI styling APIs from feature views.

| Modifier / API | Use for |
|----------------|---------|
| `.trinketScreenBackground()` | Shared tab/screen canvas (`ThemePalette.trinket.appBackground`) |
| `.trinketSurface(_:)` | Panels, cards, rows, selected/disabled/warning/reward states |
| `.trinketMaterial(_:)` | Bottom bars, popovers, reward reveals; modal uses solid surface; toolbar passes through |
| `.trinketGlassChip()` | Glass capsule chips via shared `TrinketGlassBackgroundModifier` |
| `.trinketTypography(_:)` | Scalable text hierarchy (`TypographyRole`) |
| `.trinketCardSurface()` | 3:4 card identity tiles |
| `ArtworkPickerSelectionBadge` / `.trinketArtworkPickerSelectionBorder(isSelected:color:)` | Selected artwork picker checkmark + stroke |
| `.trinketLockedCardEffect(isLocked:text:cornerRadius:)` | Subtle desaturation + opaque content blur, larger secondary-grey lock icon |
| `.trinketPrimaryActionButton()` | Primary CTAs (`.glassProminent`) |
| `.trinketStatusBadge()` / `.trinketWalletPill()` | Glass capsule chips via shared `TrinketGlassBackgroundModifier` |
| `.trinketOnArtText(_:)` | Paper foreground + ink shadows on hero art |
| `TrinketHeroScrim.gradient(for:)` | Homestead / detail / chapter hero readability scrims |
| `.trinketArtworkBlend(_:)` | Optional `.perimeter` or `.bottom` blend into a semantic destination surface; defaults to `.none` |
| `.trinketSensoryFeedback(_:trigger:enabled:)` | Gate `.sensoryFeedback` on Options haptics toggle |

Glass chrome routes through `.glassEffect` in `TrinketDesignSystem` (feature views must not call raw glass APIs). Deployment target is iOS 26.0 only.

Artwork blends should replace an overlapping edge scrim rather than stack with it. Use `.perimeter(into:)` for bounded thumbnails and cards, `.bottom(into:)` for full-bleed art meeting a lower surface, and `.none` when artwork should retain a crisp edge. Keep text-only contrast treatments such as `.trinketOnArtText(_:)` when they serve a separate readability purpose.

Platform API notes and deprecated patterns: `Docs/Platform/iOS26AppleReference.md`. Fluid motion: `Docs/Skills/apple-design/SKILL.md` (`TrinketMotion`). Dense content stays on solid themed surfaces; glass belongs on chrome and selective overlays. Standing stack rules: `Docs/Platform/Architecture.md`.
