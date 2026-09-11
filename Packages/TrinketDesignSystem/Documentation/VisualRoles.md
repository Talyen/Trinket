# Visual roles

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
| Resources | `HomesteadResource.tint` (gold resolves to the theme accent) | `ResourceWood` … `ResourceHide` / `ResourceCrystal` |
| Chapter | `TrinketDesign.Colors.chapterForest` / `.chapterDungeon` / `.chapterDesert` / `.chapterTundra` | `ChapterForest` … `ChapterTundra` |

On-art text styling uses `.trinketOnArtText(_:)`.

**Enforcement:** `python3 ./Scripts/check-ui-style.py` fails style/CI on one-off colors. A nearby `UIStyleCheck: allow - reason` annotation is permitted only for a narrow content/art exception that the semantic API cannot express; do not use it to bypass product chrome routing. New colors = new `DesignColors` asset + public design-system API.

```sh
./Scripts/test-package.sh TrinketDesignSystem
```

## Typography

Use `.trinketTypography(_:)` for all readable text. Do not call raw `.font(...)` for copy.

| Role family | Typeface | Use for |
|---|---|---|
| `*Display` (`screenDisplay`, `sectionDisplay`, `rowDisplay`) | Serif (New York) | Branded heroes and journey names on art |
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

## Game icons

Use bundled Lucide icons for game concepts, including game imagery inside buttons.
Keep SF Symbols for native navigation, menus, filters, playback, settings, alerts,
locks/checks, empty-state UI, and existing symbol animations. An SF Symbol remains
appropriate when its silhouette communicates a game concept better; Thorns uses
`burst.fill` with Physical's color. Floating combat feedback uses SF Symbols,
filled where available, for legibility over moving artwork; its presentation is
owned by [BattleFeature](../../TrinketBattleFeature/README.md#uikit-feedback-island).
Painted artwork remains primary outside symbolic feedback. [Game icon selections](../../../Docs/Product/GameIcons.md)
records surface mappings and links to the individual talent/node selections.

`GameIcon` identifies `.lucide(name)` or `.system(name)`. `GameIconImage` follows
the surrounding `trinketTypography` font through native font resolution and aligns
Lucide artwork to its text baseline. Icons are decorative; apply tint at the call
site and meaningful accessibility labels to their containing controls. It does not
add symbol effects to Lucide assets.
Feature views must not look up asset names or package bundles directly.

The selected SVGs in `Resources/GameIcons.xcassets` are vendored from Lucide 1.37.0.
Geometry and the standard two-unit stroke are unchanged; `currentColor` is
normalized to black for Xcode template rendering. `LucideProvenance.json` records
the upstream version and original SHA-256 for each icon. `Lucide-LICENSE.txt` ships
the upstream license and copyright notices. Bundle only selected assets, retain
transparent backgrounds, and verify additions through the asset-catalog test.
