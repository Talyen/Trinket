# 01. Native UI Layout, Typography & Adaptation Audit

**Goal:** Migrate unjustified custom sizing, layout, typography, adaptation, and native-control patterns toward Apple/SwiftUI-native APIs and tokens already in `TrinketDesignSystem`, without losing justified game UI.

Prereads: `Packages/TrinketDesignSystem/README.md`, `Docs/Platform/iOS26AppleReference.md`.

## Intent

Reduce unjustified custom layout/typography and confirmed non-adaptive UI while preserving intentional game UI. Prefer existing DesignSystem tokens. Add a shared token/helper only for at least three current uses or one existing DesignSystem boundary, and only when removing call-site surface outweighs the new API; otherwise simplify locally. After confirming a problem in a shared component or component family, inventory its affected call sites and migrate the confirmed cluster together.

**Principles:** one spacing scale (`TrinketDesign.Metrics`); delete parallel systems; typography that scales (`Font.TextStyle` / `.trinketTypography` / `@ScaledMetric`); don’t invent a second platform — prefer `containerRelativeFrame`, adaptive grids, `Layout`, and DesignSystem glass/button styles.

## Hard stops

- Do not redesign battle battlefield geometry or product composition unsupervised. A bounded migration to native/adaptive APIs may ship when it preserves the existing constraints, includes runtime evidence, and can be verified as one phase.
- Do not replace intentional game juice: combat float keyframe recipes, `trinketCombatFloatText` shadows, 3:4 card identity (`TrinketDesign.cardShape`).
- Do not hand-roll materials / glass / primary buttons — use DesignSystem (`check-ui-style.sh`).

## Severity

| Sev | Cluster | Typical signal |
|-----|---------|----------------|
| P1 | Broken adaptation / native behavior | Confirmed clipping, unreachable controls, unsafe-area or keyboard obstruction, or layout failure under supported Dynamic Type/localization |
| P2 | Typography / scale / container gaps | Point-sized fonts; non-scaling text bands; fixed frames or scale-down that fail supported content; avoidable custom control behavior |
| P3 | Token / spacing consistency | Raw spacing next to existing Metrics; duplicated constants; manual insets before surface modifiers when the visible result remains correct |

## Domain rules & allowlists

- Prefer native SwiftUI modifiers (`.font()`, `.foregroundStyle()`, `.padding()`, `.grid()`) over custom utility wrappers.
- Respect Apple Human Interface Guidelines (HIG) for dynamic type, accessibility, and platform-native layout behaviors.
- Route structural duplications (e.g. repeated screen scaffolding across 3+ files) to `09_DuplicateFeatureSurfaceAudit.md`. Same grid / scaffolding structure repeated across 3+ files, or across two substantial surfaces with demonstrated drift or shared defects, is a duplicate feature surface — route it to `09_DuplicateFeatureSurfaceAudit.md` rather than fixing it as a token migration.

**Leave alone (justified custom):** fanned battle hand + drag-to-play; hero rubber-band overscroll; combat float motion recipes / outline shadows; health-bar `GeometryReader` fills; decorative SF Symbols already on `@ScaledMetric`.

**Tie-breakers:** repair visible adaptation and native control behavior before cosmetic token consistency; adopt existing tokens over new APIs; duplicated constants over one-off sizes; extract/document justified custom over rewriting it. Shared accessibility behavior follows PD-007 and the UI Interaction audit.

## Domain rules

Prefer `TrinketDesign.Metrics`, `Corners`, `.trinketTypography`, `.trinketSurface`, `.trinketGlassChip`, `.trinketPrimaryActionButton`. Surfaces already pad — do not stack extra padding then `.trinketSurface` unless the role is `.card`. Prefer growing containers in scroll contexts over `minimumScaleFactor`; account for Dynamic Type, localization expansion, safe areas, and keyboard presentation before fixing dimensions. Prefer native controls and container APIs when they preserve the game interaction. Gesture-driven motion should track 1:1 during drag, respect applicable reduced-motion behavior, and settle with interruptible springs (`TrinketMotion`).

Successful fixes show a net reduction or neutral move in custom layout/typography constants toward tokens or native APIs.
