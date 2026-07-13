# Native UI Layout & Typography Audit

**Goal:** Find custom sizing, layout, typography, and scale patterns that diverge from Apple/SwiftUI-native APIs (or from tokens already in `TrinketDesignSystem`), then migrate the highest-ROI cluster toward platform standards without losing justified game UI.

**Siblings:** interaction/a11y → [UIInteractionFeedbackAudit.md](UIInteractionFeedbackAudit.md). Prereads: `Packages/TrinketDesignSystem/README.md`, `Docs/Platform/iOS26AppleReference.md`.

## Intent

Inventory custom vs tokenized vs justified-custom, then fix **one** cluster — prefer adopting existing DesignSystem tokens over inventing new systems.

**Principles:** one spacing scale (`TrinketDesign.Metrics`); delete parallel systems; typography that scales (`Font.TextStyle` / `.trinketTypography` / `@ScaledMetric`); don’t invent a second platform — prefer `containerRelativeFrame`, adaptive grids, `Layout`, and DesignSystem glass/button styles.

## Hard stops

- Cap: **one cluster** — not a repo-wide sweep or full-tab visual redesign.
- Do not rewrite battle battlefield proportional layout in one pass.
- Do not replace intentional game juice: combat float keyframe recipes, `trinketCombatFloatText` shadows, 3:4 card identity (`TrinketDesign.cardShape`).
- Do not hand-roll materials / glass / primary buttons — use DesignSystem (`check-ui-style.sh`).

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

**Leave alone (justified custom):** fanned battle hand + drag-to-play; hero rubber-band overscroll via `onScrollGeometryChange`; combat float motion recipes / outline shadows; health-bar `GeometryReader` fills; decorative SF Symbols already on `@ScaledMetric`.

**Tie-breakers:** (1) adopt existing tokens over new APIs, (2) visible UI clarity and native control behavior over cosmetic spacing, (3) duplicated constants over one-off sizes, (4) extract/document justified custom over rewriting it. Comprehensive accessibility work follows PD-007 rather than this audit.

## Domain rules

Prefer `TrinketDesign.Metrics`, `Corners`, `.trinketTypography`, `.trinketSurface`, `.trinketGlassChip`, `.trinketPrimaryActionButton`. Surfaces already pad — do not stack extra padding then `.trinketSurface` unless the role is `.card`. Prefer growing containers in scroll contexts over `minimumScaleFactor`. Gesture-driven motion: 1:1 tracking during drag; settle with interruptible springs (`TrinketMotion`).

## Probe hints

Hardcoded stack spacing / padding; point-sized fonts; `GeometryReader` / `PreferenceKey` / custom `Layout`; duplicated `GridItem(.adaptive)`; DesignSystem adoption gaps; fixed text bands (`cardLabelReservedHeight`, `minimumScaleFactor`).

## Verify

`check-ui-style.sh` + lint; `test-package.sh TrinketDesignSystem` for chrome/motion/typography; focused unit/smoke when app layout or identifiers change. When Simulator is available, spot-check the supported visual layout on the chosen screen.
