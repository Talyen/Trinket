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

Use SF Symbols for game concepts and native UI. Prefer filled variants when they
retain the intended meaning; symbols such as `asterisk`, `snowflake`, `wind`, and
`sparkles` do not need a fill variant. Preserve native font weight, scale, and
symbol behavior. Painted artwork remains primary outside symbolic feedback.
[Game icon selections](../../../Docs/Product/GameIcons.md) records shared mappings
and links to individual talent and Homestead selections.

`GameIcon` identifies `.system(name)`. `GameIconImage` renders a native SwiftUI
symbol in monochrome, inheriting the surrounding typography and tint. Icons are
decorative; provide meaningful accessibility labels on their containing controls.
Floating combat feedback consumes the same `Keyword.visualStyle.icon` identities;
its rasterization and motion remain owned by
[BattleFeature](../../TrinketBattleFeature/README.md#uikit-feedback-island).

Authored content uses `sf:` identifiers. `GameIcon.init(id:)` also accepts legacy
unqualified SF names and translates the previously shipped `lucide:` names through
`GameIcon+Legacy.swift`. This read compatibility does not require Lucide assets or
a second renderer. Do not add new entries to the legacy provider vocabulary.
