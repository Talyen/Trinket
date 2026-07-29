# Native UI Layout & Typography Audit

**Goal:** Migrate unjustified custom sizing, layout, typography, and scale patterns toward Apple/SwiftUI-native APIs and tokens already in `TrinketDesignSystem`, without losing justified game UI.

Prereads: `Packages/TrinketDesignSystem/README.md`, `Docs/Platform/iOS26AppleReference.md`.

## Intent

Reduce unjustified custom layout/typography while preserving intentional game UI. Prefer existing DesignSystem tokens. Add a shared token/helper only for at least three current uses, and only when removing call-site surface outweighs the new API; otherwise simplify locally. Planning and phasing: [README.md](README.md).

**Principles:** one spacing scale (`TrinketDesign.Metrics`); delete parallel systems; typography that scales (`Font.TextStyle` / `.trinketTypography` / `@ScaledMetric`); don’t invent a second platform — prefer `containerRelativeFrame`, adaptive grids, `Layout`, and DesignSystem glass/button styles.

## Hard stops

- Do not rewrite battle battlefield proportional layout unsupervised in one pass — include a scoped migration phase if that is part of the plan.
- Do not replace intentional game juice: combat float keyframe recipes, `trinketCombatFloatText` shadows, 3:4 card identity (`TrinketDesign.cardShape`).
- Do not hand-roll materials / glass / primary buttons — use DesignSystem (`check-ui-style.sh`).

## Severity

Shared scale: [README.md](README.md).

| Sev | Cluster | Typical signal |
|-----|---------|----------------|
| P1 | Spacing / padding literals | Raw spacing next to existing Metrics; manual insets before glass/wallet/badge modifiers |
| P2 | Typography / scale gaps | Point-sized fonts; roles unused where they map; non-scaling text bands |
| P3 | Justified custom / competing rules | Keep product behavior; extract/document constants or one shared layout helper |

Same grid / scaffolding structure repeated across 3+ files is a duplicate feature surface — route it to DuplicateFeatureSurfaceAudit rather than fixing it as a token migration.

**Leave alone (justified custom):** fanned battle hand + drag-to-play; hero rubber-band overscroll; combat float motion recipes / outline shadows; health-bar `GeometryReader` fills; decorative SF Symbols already on `@ScaledMetric`.

**Tie-breakers:** adopt existing tokens over new APIs; visible UI clarity and native control behavior over cosmetic spacing; duplicated constants over one-off sizes; extract/document justified custom over rewriting it. Comprehensive accessibility work follows PD-007 rather than this audit.

## Domain rules

Prefer `TrinketDesign.Metrics`, `Corners`, `.trinketTypography`, `.trinketSurface`, `.trinketGlassChip`, `.trinketPrimaryActionButton`. Surfaces already pad — do not stack extra padding then `.trinketSurface` unless the role is `.card`. Prefer growing containers in scroll contexts over `minimumScaleFactor`. Gesture-driven motion should track 1:1 during drag and settle with interruptible springs (`TrinketMotion`).

Successful fixes show a net reduction or neutral move in custom layout/typography constants toward tokens or native APIs.
