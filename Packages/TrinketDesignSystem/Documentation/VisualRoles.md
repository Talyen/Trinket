# Visual roles

## Color families

All production colors load from `DesignColors.xcassets` through `DesignAssetColors`.

| Family | Public API | Assets |
|---|---|---|
| Theme chrome | `TrinketDesign.Colors.canvas/surface/panel/…/accent/success/…` | `ThemeCanvas`, `ThemeSurface`, … |
| Gameplay health | `TrinketDesign.Colors.health`, `.healthRestore`, battle derived opacities | `ThemeHealth`, `ThemeHealthRestore` |
| Overlays | `TrinketDesign.Colors.Overlay.ink/paper/…` | `ThemeOverlayInk`, `ThemeOverlayPaper` |
| Battle slice | `TrinketDesign.Colors.battleSliceCrack` / `.battleSliceSpark` | `BattleSliceCrack`, `BattleSliceSpark` |
| Keywords | `Keyword.visualStyle.color` (`TrinketDesign.Colors.keyword*`; `gold` aliases accent, `thorns` aliases `keywordPhysical`) | `KeywordPhysical` … `KeywordDeathsDoor` |
| Encounters | `TrinketDesign.Colors.encounter*` | `EncounterBattle` … |
| Placeholders | `TrinketDesign.CardPlaceholderStyle.*` (`TrinketDesign.Colors.placeholder*`) | `PlaceholderHero` … |
| Resources | `HomesteadResource.tint` (`TrinketDesign.Colors.resource*`; gold resolves to the theme accent) | `ResourceWood` … `ResourceHide` / `ResourceGems` |
| Chapter | `TrinketDesign.Colors.chapterForest` / `.chapterDungeon` / `.chapterDesert` / `.chapterTundra` | `ChapterForest` … `ChapterTundra` |

On-art text styling uses `.trinketOnArtText(_:)`.

**Enforcement:** `python3 ./Scripts/check-ui-style.py` fails style/CI on one-off colors. A nearby `UIStyleCheck: allow - reason` annotation is permitted only for a narrow content/art exception that the semantic API cannot express; do not use it to bypass product chrome routing. New colors = new `DesignColors` asset + public design-system API.

```sh
./Scripts/test-package.sh TrinketDesignSystem
```

## Typography

Use `.trinketTypography(_:)` for all readable text. Do not call raw `.font(...)` for copy. Symbol/glyph sizing (placeholder art, lock glyphs) is the exception: it uses explicit sizes since it sizes artwork rather than styling copy — placeholder art carries a narrow `UIStyleCheck: allow`, and the lock glyph sits inside the design-system helpers allowlisted in `check-ui-style.py`.

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

Use semantic modifiers (`.trinketSurface(.secondary)`, `.trinketScreenBackground()`) instead of hardcoded colors. Roles are `secondary`, `card`, and `denseRow`.

## Keyword styling

Every keyword has one visual identity via `Keyword.visualStyle`. Do not introduce one-off keyword colors in feature views.

## Game icons

Use SF Symbols for game concepts and native UI. Prefer filled variants when they
retain the intended meaning; symbols such as `asterisk`, `snowflake`, `wind`, and
`sparkles` do not need a fill variant. Preserve native font weight, scale, and
symbol behavior. Painted artwork remains primary outside symbolic feedback.
[Game icon selections](../../../Docs/Product/GameIcons.md) records shared mappings
and links to individual talent and Homestead selections.

Check each new symbol and symbol effect against the minimum supported OS; the
current SF Symbols app can include names available only on newer releases. Use an
availability-gated newer symbol where it materially improves communication, with
an existing symbol on the older supported OS. Keep stable gameplay identities;
do not change serialized icon IDs merely to animate a presentation. Review symbols
at the surrounding text's weight and scale and over their actual backgrounds.

`GameIcon` identifies `.system(name)`. `GameIconImage` renders a native SwiftUI
symbol in monochrome, inheriting the surrounding typography and tint. Icons are
decorative; provide meaningful accessibility labels on their containing controls.
Floating combat feedback consumes the same `Keyword.visualStyle.icon` identities;
its rasterization and motion remain owned by
[BattleFeature](../../TrinketBattleFeature/README.md#uikit-feedback-island).

Authored content uses `sf:` identifiers. `GameIcon.init(id:)` also accepts bare
(unqualified) SF names, which resolve identically.
