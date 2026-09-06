# 01. Native UI Layout, Typography & Adaptation Audit

**Goal:** Improve native layout, typography, and adaptation while preserving
Trinket's intentional game UI.

Use the [shared audit contract](README.md) for evidence, severity, scope, and sizing.
[TrinketDesignSystem](../../Packages/TrinketDesignSystem/README.md) and
[iOS reference](../Platform/iOS26AppleReference.md) own native API/token guidance;
[PD-014](../Product/Decisions.md) owns accessibility scope.

## What to investigate

Clipped or unreadable content, containers that fail to accommodate their content,
safe-area or keyboard conflicts, inconsistent native-control behavior, and custom
layout/typography that duplicates an existing capability with real maintenance cost.
Consider supported screen sizes and content expansion without inventing product
requirements. A raw constant or custom modifier alone is not a defect.

## Domain boundaries

- Preserve battlefield composition, fanned hand/drag-to-play, hero overscroll,
  combat-float motion, and 3:4 card identity. Native APIs are useful when they
  preserve those constraints, not a reason to redesign them.
- Use the existing spacing/layout, typography, glass, surface, and button owners;
  do not create a competing token system. Health-bar geometry fills and decorative
  symbols already using scaled metrics can be intentional.
- Preserve existing accommodation behavior; do not add bespoke accessibility modes
  or setting-specific layout branches under PD-014.
- Repeated product scaffolding with demonstrated co-maintenance belongs to
  [09](09_DuplicateFeatureSurfaceAudit.md); unusable gestures/actions belong to
  [16](16_UIInteractionFeedbackAudit.md).

## Evidence and success

Show a concrete adaptation/native-behavior failure or avoidable custom maintenance,
then verify that the remedy preserves intended constraints. Visible layout and
battlefield adaptations need runtime evidence at the affected conditions.
Source can establish an enforced style violation; a token substitution alone does
not establish better UX. Success is usable adaptation or simpler supported layout,
not a mandatory reduction in constants, wrappers, or lines.
