# 09. Duplicate Feature Surface Audit

**Goal:** Reduce repeated maintenance and divergent behavior in equivalent product
presentation while preserving meaningful differences between flows.

Use the [shared audit contract](README.md) for scope, evidence, severity, and sizing.
[Architecture](../Platform/Architecture.md) owns shared UI and feature boundaries.

## Evidence

Compare screens, shells, pickers, summary grids, and repeated loading/error/empty
states by responsibility and interaction contract, not visual resemblance alone.
Confirm a shared defect, inconsistent fixes, or repeated edits to the same behavior.
There is no fixed call-site threshold: two costly twins may justify a remedy,
while many simple similar views may remain clearer independently.

## Remedy and success

Choose the smallest coherent presentation slice that removes the demonstrated
co-maintenance. Deleting a redundant path, reusing an existing component, or sharing
a local layout can be enough; one parameterized screen is not a required outcome.
Include repeated state mapping, identifiers, and tests only when they belong to
that same confirmed duplication.

Keep content bindings and distinct mode rules with their feature. Shared game UI
belongs in the existing feature-support owner; app chrome/tokens belong in the
design system. A configuration object full of mode flags can cost more than the
original duplication. Verify each affected flow still honors its own contract and
that the old repeated responsibility has actually been removed.

## Boundaries

Do not unify unrelated interactions such as the battle hand and collection grid
merely because both display cards. Preserve mystery/shop rules and each Play mode's
progression. Single-path ceremony belongs to
[06](06_DeadParallelCeremonialSurfaceAudit.md); native layout/adaptation defects
belong to [01](01_AppleNativeUIAudit.md).
