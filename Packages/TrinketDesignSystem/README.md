# TrinketDesignSystem

Shared app chrome — semantic surfaces, typography, keyword visuals, and reusable components. Depends on `TrinketCore` only (no `BattleEngine` or `TrinketContent`).

## Components

| File | Role |
|------|------|
| `TrinketDesign.swift` | Colors, metrics, overlays, and card chrome |
| `DesignAssetColors.swift` | Package-bundled semantic color assets (`Bundle.module`) |
| `Resources/DesignColors.xcassets` | Theme, keyword, encounter, placeholder, resource, chapter color sets |
| `VisualFoundation.swift` | Background modes, surface roles, spacing tokens |
| `HeroScrim.swift` | On-art text styling (`.trinketOnArtText`) |
| `ArtworkBlend.swift` | Optional semantic bottom-edge artwork blending |
| `Keyword+VisualStyle.swift` | Color + SF Symbol per Keyword |
| `HomesteadResource+Color.swift` | Homestead resource tint resolution |
| `Modifiers.swift` | Semantic view modifiers for backgrounds, surfaces |
| `ExperienceBar.swift` | XP/level progress bar |
| `TrinketMotion.swift` | Motion recipes shared by multiple product features |

## Color families

All production colors load from `DesignColors.xcassets` through `DesignAssetColors`.

| Family | Public API | Assets |
|---|---|---|
| Theme chrome | `TrinketDesign.Colors.canvas/surface/panel/…/accent/success/…` | `ThemeCanvas`, `ThemeSurface`, … |
| Gameplay health | `TrinketDesign.Colors.health`, `.healthRestore`, battle derived opacities | `ThemeHealth`, `ThemeHealthRestore` |
| Overlays | `TrinketDesign.Colors.Overlay.ink/paper/…` | `ThemeOverlayInk`, `ThemeOverlayPaper` |
| Keywords | `Keyword.visualStyle.color` | `KeywordPhysical` … `KeywordDeathsDoor` |
| Encounters | `TrinketDesign.Colors.encounter*` | `EncounterBattle` … |
| Placeholders | `TrinketDesign.CardPlaceholderStyle.*` | `PlaceholderHero` … |
| Resources | `HomesteadResource.tint` | `ResourceWood` … `ResourceHide` / `ResourceCrystal` (+ gold via KeywordGold) |
| Chapter | `TrinketDesign.Colors.chapterForest` / `.chapterDungeon` / `.chapterDesert` / `.chapterTundra` | `ChapterForest` … `ChapterTundra` |

On-art text styling uses `.trinketOnArtText(_:)`.

**Enforcement:** `./Scripts/check-ui-style.sh` fails style/CI on one-off colors. A nearby `UIStyleCheck: allow - reason` annotation is permitted only for a narrow content/art exception that the semantic API cannot express; do not use it to bypass product chrome routing. New colors = new `DesignColors` asset + public design-system API.

```sh
./Scripts/test-package.sh TrinketDesignSystem
```

## Typography

Use `.trinketTypography(_:)` for all readable text. Do not call raw `.font(...)` for copy.

| Role family | Typeface | Use for |
|---|---|---|
| `*Display` (`screenDisplay`, `sectionDisplay`, `rowDisplay`) | SF Pro | Heroes and journey names on art |
| `*Title` (`screenTitle`, `sectionTitle`, `cardTitle`) | SF Pro | Apple-native UI chrome, lists, shelves |
| `eyebrow` | SF caption bold | Label **above** a hero title (chapter, role, rarity) |
| Body / caption / badge / button / statValue / … | SF Pro | Supporting copy and controls |

Hero stack order is always **eyebrow → title** (never title then rarity/role).

### Detail sheet ladder

Hero / Companion / Enemy / Ability / Item detail sheets share one body ladder (via `DetailSection` + pane copy). Remap at the sheet call sites — do not change these roles’ fonts globally.

| Layer | Role | Color |
|---|---|---|
| Section header | `.rowTitle` | `.primary` |
| Named entries (e.g. trait names) | `.cardTitle` | `.primary` |
| Reading copy (effects, affixes, blurbs) | `.body` | `.secondary` |
| Stat labels / values | `.body` / `.statValue` | `.primary` / `.secondary` |
| On-art eyebrow / title | `.eyebrow` / `.screenDisplay` | `.trinketOnArtText` |

## Surface roles

Use semantic modifiers (`.trinketSurface(.base)`, `.trinketScreenBackground()`) instead of hardcoded colors. Roles include `base`, `secondary`, `elevated`, `card`, `denseRow`, `selected`, `disabled`, `warning`, `reward`.

## Keyword styling

Every keyword has one visual identity via `Keyword.visualStyle`. Do not introduce one-off keyword colors in feature views.

## Modern API Inventory

Route recurring chrome through these modifiers — do not call raw SwiftUI styling APIs from feature views.

| Modifier / API | Use for |
|----------------|---------|
| `.trinketScreenBackground()` | Shared tab/screen canvas (`TrinketDesign.Colors.canvas`) |
| `.trinketSurface(_:)` | Panels, cards, rows, selected/disabled/warning/reward states |
| `.trinketMaterial(_:)` | Bottom bars, popovers, reward reveals; modal uses solid surface; toolbar passes through |
| `.trinketGlassChip()` | Glass capsule chips via shared `TrinketGlassBackgroundModifier` |
| `.trinketTypography(_:)` | Scalable text hierarchy (`TypographyRole`) |
| `.trinketCardSurface()` | 3:4 card identity tiles |
| `ArtworkPickerSelectionBadge` / `.trinketArtworkPickerSelectionBorder(isSelected:color:)` | Selected artwork picker checkmark + stroke |
| `.trinketLockedCardEffect(isLocked:cornerRadius:)` | Subtle desaturation + opaque content blur, larger opaque paper lock with ink edge contrast |
| `TrinketDesign.Metrics.collectionGridItems` / `.partyPickerGridItems` / `.hubGridItems(for:)` | Shared collection, party-picker, and size-class hub grids |
| `TrinketDesign.Metrics.collectionShelfPreviewLimit` | Peek-shelf card count for Collection / party shelves |
| `.trinketPrimaryActionButton()` | Primary CTAs (`.glassProminent`) |
| `.trinketCenteredPrimaryAction()` | Half-width, centered layout for a lone screen primary action |
| `.trinketQuietTapButtonStyle()` | Tap without press dimming — prefer over `.plain` for artwork in scroll views |
| `.trinketOnArtText(_:)` | Paper foreground + ink shadows on hero art |
| `.trinketArtworkBlend(_:)` | Optional `.bottom` blend into a semantic destination surface; defaults to `.none` |
| `.trinketSensoryFeedback(_:trigger:enabled:)` | Gate `.sensoryFeedback` on Options haptics toggle |

Glass chrome routes through `.glassEffect` inside this package only.

Artwork blends provide a transition into destination surfaces. Use `.bottom(into:)` for full-bleed art meeting a lower surface, and `.none` when artwork should retain a crisp edge. Keep text-only contrast treatments such as `.trinketOnArtText(_:)` when they serve a separate readability purpose.

Platform API notes: [iOS26AppleReference.md](../../Docs/Platform/iOS26AppleReference.md). Fluid motion: [apple-design skill](../../.agents/skills/apple-design/SKILL.md) (`TrinketMotion`). Standing stack rules: [Architecture.md](../../Docs/Platform/Architecture.md).
