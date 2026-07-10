# Native UI Layout & Typography Audit

Goal: Find custom sizing, layout, typography, padding, fonts, and scale patterns that diverge from Apple/SwiftUI-native APIs (or from tokens already in `TrinketDesignSystem`), then migrate the highest-ROI cluster toward platform standards without losing justified game UI.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

UI interaction and accessibility → [UIInteractionFeedbackAudit.md](UIInteractionFeedbackAudit.md). General simplification belongs in normal change review, not a separate autonomous audit.

## Mission

1. Read `AGENTS.md`, `Packages/TrinketDesignSystem/README.md`, and `Docs/Platform/iOS26AppleReference.md`
2. Run the probes below; inventory custom vs tokenized vs justified-custom
3. Pick **one** cluster (see Triage) — prefer adopting existing DesignSystem tokens over inventing new systems
4. Fix that cluster only (cap blast radius)
5. Verify style gate + focused tests
6. Commit

Guiding principles (Apple design / SwiftUI):

- **Spatial consistency** — one spacing scale (`TrinketDesign.Metrics`), not per-screen magic numbers
- **Restraint** — delete parallel systems; route through DesignSystem
- **Typography that scales** — semantic `Font.TextStyle` / `.trinketTypography` / `@ScaledMetric`; no fixed point sizes for UI copy
- **Don’t invent a second platform** — prefer `containerRelativeFrame`, `LazyVGrid` + `.adaptive`, `onScrollGeometryChange`, `Layout`, glass/button styles already wrapped by DesignSystem

## Hard stops

- Do not restyle unrelated chrome or rewrite battle battlefield proportional layout in one pass.
- Do not replace intentional game juice: combat float keyframe recipes, `trinketCombatFloatText` shadows, 3:4 card identity (`TrinketDesign.cardShape`).
- Do not hand-roll materials / glass / primary buttons — use DesignSystem (`./Scripts/check-ui-style.sh`).
- Do not add `#available` for older iOS; deployment target is iOS 26+.
- Do not introduce `NavigationView`, `ObservableObject`, `@StateObject`, or `@Published`.
- Do not hand-edit `Generated/`, `.DerivedData/`, or processed assets.
- Do not expand into full-tab visual redesigns or Homestead one-off metric taxonomies unless that is the chosen cluster.
- Cap: **one cluster** (e.g. Metrics adoption, typography roles, one layout extract) — not a repo-wide sweep.

## Probes

```bash
# Style gate (materials / buttons)
./Scripts/check-ui-style.sh

# Hardcoded spacing / padding / frames
rg -n 'VStack\(spacing:\s*\d+|HStack\(spacing:\s*\d+|LazyVStack\(spacing:\s*\d+|\.padding\(\d+\)|\.padding\(\.(horizontal|vertical),\s*\d+\)' \
  --type swift Trinket/ Packages/TrinketDesignSystem/Sources/ -g '!**/Generated/**'

# Point-sized fonts (UI copy / icons)
rg -n '\.font\(\.system\(size:|Font\.system\(size:' --type swift Trinket/ Packages/TrinketDesignSystem/Sources/ -g '!**/Generated/**'

# Custom measurement / layout
rg -n 'GeometryReader|PreferenceKey|containerRelativeFrame|onScrollGeometryChange|struct \w+: Layout' \
  --type swift Trinket/ Packages/TrinketDesignSystem/Sources/ -g '!**/Generated/**'

# Grid duplication
rg -n 'GridItem\(\.adaptive' --type swift Trinket/

# DesignSystem adoption gaps
rg -n 'trinketTypography|TrinketDesign\.Metrics' --type swift Trinket/ | head -60
rg -n 'TypographyRole|func trinketTypography' --type swift Packages/TrinketDesignSystem/

# Shrink-to-fit / fixed text bands
rg -n 'minimumScaleFactor|cardLabelReservedHeight|trinketCardLabelSpace' --type swift Trinket/ Packages/TrinketDesignSystem/
```

Inventory dumps are for triage, not mandatory file-by-file review.

## Triage (pick one cluster)

| Priority | Cluster | Typical signal | Preferred remediation |
|----------|---------|----------------|------------------------|
| 1 | Spacing / padding literals | Raw `8`/`12`/`24` next to existing Metrics | Map to `TrinketDesign.Metrics.*`; strip double-padding on `.trinketSurface` |
| 1 | Chip / wallet padding | Manual insets before `trinketGlassChip` / wallet / badge | Bake into DesignSystem modifiers; remove call-site padding |
| 1 | Duplicated grids | Same `GridItem(.adaptive(…))` in 3+ files | Shared `TrinketDesign.Metrics.collectionGridItems` (or party variant) |
| 2 | Typography roles unused | `.font(.headline)` everywhere; zero `.trinketTypography` | Adopt roles where they map; leave `.title` / `.title2` / `.caption2` if no role |
| 2 | Fixed point fonts | Combat float `fontSize`, cinematic glyphs | `Font.TextStyle` + `.rounded` / `@ScaledMetric` / semantic symbol fonts |
| 2 | Non-scaling text bands | Fixed `cardLabelReservedHeight` | `@ScaledMetric(relativeTo:)` or grow with `fixedSize` |
| 3 | Justified custom layout | Battle hand fan, hero overscroll | Extract constants / small `Layout` type; **keep** product behavior |
| 3 | Competing size rules | Hero min-300 vs scrim 140 vs picker 133 | One documented rule in a shared layout helper |

**Leave alone (justified custom):**

- Fanned battle hand + drag-to-play (no first-party card-fan API) — extract metrics, don’t delete
- Hero rubber-band overscroll via `onScrollGeometryChange` (Photos-like) — unify heights, don’t replace with `safeAreaBar`
- Combat float motion recipes / outline shadows
- Health-bar `GeometryReader` fills (normal progress chrome)
- Decorative SF Symbols already on `@ScaledMetric` (Phase C pattern)

**Tie-breakers:** (1) adopt existing tokens over new APIs, (2) Dynamic Type / a11y gaps over cosmetic spacing, (3) duplicated constants over one-off Homestead sizes, (4) extract/document justified custom over rewriting it.

## Checks

### DesignSystem first

- Prefer `TrinketDesign.Metrics`, `Corners`, `.trinketTypography`, `.trinketSurface`, `.trinketGlassChip`, `.trinketPrimaryActionButton`, `collectionShelfCardWidth()`
- Add a new token only when an existing token cannot express a recurring semantic role or a shared modifier owns the value
- Surfaces already pad (role-dependent); do not stack `.padding(12/14)` then `.trinketSurface` unless the role is `.card` (padding 0)

### Typography & scale

- UI copy → semantic text styles or `.trinketTypography(TypographyRole)`
- Decorative icons → `@ScaledMetric(relativeTo:)` or semantic symbol font — not bare `size: N`
- Avoid new `.dynamicTypeSize(…)` caps unless a layout truly cannot grow
- Prefer growing containers in scroll contexts over `minimumScaleFactor` shrink-to-fit

### Layout

- Prefer `containerRelativeFrame`, adaptive `LazyVGrid`, `scrollTargetLayout` / `.viewAligned` when they fit
- Custom `GeometryReader` math → extract to a named layout helper (or `Layout` protocol) with named constants
- Gesture-driven motion: 1:1 tracking during drag; settle with interruptible springs (`TrinketMotion`) from the presentation value

### Anti-patterns

- Parallel spacing enums in feature folders
- Point-size font recipes that ignore Dynamic Type
- Copy-pasted `GridItem` tuples
- “Nativizing” combat VFX into stock transitions
- Broad restyles under the guise of token adoption

## Verification

```sh
./Scripts/check-ui-style.sh
./Scripts/lint.sh
# Package chrome / motion / typography changes:
./Scripts/test-package.sh TrinketDesignSystem
# App layout helpers / orchestration:
./Scripts/test.sh unit <RelevantTestClass>
# If tab chrome or identifiers changed (toolchain permitting):
./Scripts/test.sh smoke
```

When a Simulator or device is available, inspect the chosen screen at its relevant Dynamic Type size and compare the changed layout before declaring success. Cloud / no-Xcode: still land source fixes; skip visual/build/test checks and state skips in the commit body (see [README.md](README.md)).

## Commit

```
refactor(ui): <imperative native-layout/typography simplification>

- <cluster + what moved to Metrics / TypographyRole / layout helper>
- check-ui-style + <tests run>

User-Facing: yes | no
```

Summarize inventory highlights and the chosen cluster in the commit body — **not** in this audit file.
