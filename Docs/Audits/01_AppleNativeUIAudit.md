# 01. Native Layout, Typography & Adaptation Audit

**Goal:** Improve native layout, typography, and adaptation while preserving
Trinket's intentional game UI.

Use the [shared audit contract](README.md) for evidence, severity, scope, and sizing.
[TrinketDesignSystem](../../Packages/TrinketDesignSystem/README.md) and
[platform reference](../Platform/ApplePlatformReference.md) own native API/token guidance;
[PD-014](../Product/Decisions.md) owns accessibility scope.

## What to investigate

Clipped or unreadable content, containers that fail to accommodate their content,
safe-area or keyboard conflicts, inconsistent native-control behavior, and custom
layout/typography that duplicates an existing capability with real maintenance cost.
Consider supported screen sizes and content expansion without inventing product
requirements. A raw constant or custom modifier alone is not a defect.

For controls affected by the change, inspect effective touch regions and spacing
against the game-control guidance in [motion and gestures](../../.agents/skills/apple-design/motion-and-gestures.md).
Check text over actual artwork and beneath floating chrome; distinguish Liquid
Glass controls from content surfaces and retain native scroll-edge separation.
When reviewing a new OS, use the [release-readiness checks](../Platform/Verification.md#new-ios-release-readiness)
rather than treating the minimum deployment target as the only supported runtime.

## Domain boundaries

- Preserve battlefield composition, fanned hand/drag-to-play, hero overscroll,
  combat-float motion, and 3:4 card identity. Native APIs are useful when they
  preserve those constraints, not a reason to redesign them.
- Use the existing spacing/layout, typography, glass, surface, and button owners;
  do not create a competing token system. Health-bar geometry fills and decorative
  symbols already using scaled metrics can be intentional.
- Preserve existing accommodation behavior; do not add bespoke accessibility modes
  or setting-specific layout branches under PD-014.
- Repeated product scaffolding or unusable gestures/actions route through the
  shared confusable-pairs table.

## Evidence and success

Show a concrete adaptation/native-behavior failure or avoidable custom maintenance,
then verify that the remedy preserves intended constraints. Visible layout and
battlefield adaptations need runtime evidence at the affected conditions.
Source can establish an enforced style violation; a token substitution alone does
not establish better UX. Success is usable adaptation or simpler supported layout.
