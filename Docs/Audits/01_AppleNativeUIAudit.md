# 01. Native UI Layout, Typography & Adaptation Audit

**Goal:** Migrate unjustified custom sizing, layout, typography, adaptation, and native-control patterns toward Apple/SwiftUI-native APIs and tokens already in `TrinketDesignSystem`, without losing justified game UI.

Prereads: `Packages/TrinketDesignSystem/README.md`, `Docs/Platform/iOS26AppleReference.md`.

## Intent

Reduce unjustified custom layout/typography and confirmed non-adaptive UI while preserving intentional game UI. Add a shared token/helper only when removing call-site surface outweighs the new API under the [README right-size policy](README.md); otherwise simplify locally. After confirming a problem in a shared component or component family, inventory its affected call sites and migrate the confirmed cluster together.

**Principles:** one spacing scale (`TrinketDesign.Spacing`) and one layout-token owner (`TrinketDesign.Layout`); delete parallel systems; typography that scales (`Font.TextStyle` / `.trinketTypography` / `@ScaledMetric`); don’t invent a second platform — prefer `containerRelativeFrame`, adaptive grids, `Layout`, and DesignSystem glass/button styles.

## Hard stops

- Do not redesign battle battlefield geometry or product composition unsupervised. A bounded migration to native/adaptive APIs may ship when it preserves the existing constraints, includes runtime evidence, and can be verified as one phase.
- Do not replace intentional game juice: combat float keyframe recipes, 3:4 card identity (`TrinketDesign.cardShape`).
- Do not hand-roll materials / glass / primary buttons — use DesignSystem (`check-ui-style.py`).

Severity follows the [shared audit scale](README.md#severity-scale): prioritize
broken adaptation or native behavior, then confirmed typography/container gaps,
then cosmetic token consistency.

## Domain rules & allowlists

- Prefer native SwiftUI modifiers (`.font()`, `.foregroundStyle()`, `.padding()`, `.grid()`) over custom utility wrappers.
- Respect Apple Human Interface Guidelines for platform-native layout behaviors. Accessibility accommodation branches are out of scope (PD-014).
- Structural duplication — same grid/scaffolding across 3+ files, or two substantial surfaces with demonstrated drift or shared defects — belongs to `09_DuplicateFeatureSurfaceAudit.md`, not a token migration.

**Leave alone (justified custom):** fanned battle hand + drag-to-play; hero rubber-band overscroll; combat float motion recipes / outline shadows; health-bar `GeometryReader` fills; decorative SF Symbols already on `@ScaledMetric`.

**Tie-breakers:** repair visible adaptation and native control behavior before cosmetic token consistency; extract/document justified custom over rewriting it.

Prefer `TrinketDesign.Spacing`, `TrinketDesign.Layout`, `Corners`, `.trinketTypography`, `.trinketSurface`, `.trinketGlassChip`, `.trinketPrimaryActionButton`. Surfaces already pad — do not stack extra padding then `.trinketSurface` unless the role is `.card`. Prefer growing containers in scroll contexts over `minimumScaleFactor`; account for localization expansion, safe areas, and keyboard presentation before fixing dimensions. Prefer native controls and container APIs when they preserve the game interaction. Gesture-driven motion should track 1:1 during drag and settle with interruptible springs (`TrinketMotion`).

Successful fixes show a net reduction or neutral move in custom layout/typography constants toward tokens or native APIs.
