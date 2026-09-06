# 02. Maintenance Surface & Locality Audit

**Goal:** Reduce avoidable reading, editing, and verification cost for ordinary changes.

Use the [shared audit contract](README.md) for scope, evidence, severity, and sizing.
This audit examines live maintenance cost; the per-diff change-budget advisory
answers a different question.

## What to investigate

Mixed-job files or guidance, duplicated facts that force co-changes, scaffolding
that obscures a small behavior, and verification/diagnostics broader than the
changed behavior's dependencies require. File size, churn, or a count of touched
files is a lead, not a finding. One demonstrated costly workflow can be sufficient;
repetition strengthens evidence but there is no required instance count.

## Evidence and remedy

Name the avoidable cause and show its cost with a concrete change path, duplicated
policy/command, unnecessary prereads, verification fan-out, or diagnostic volume.
Separate necessary behavior and coverage from the excess. Prefer an existing source
of truth, removing scaffolding, or restoring a coherent job within the current owner.
A split is useful when it reduces unrelated context; a smaller file is not itself a win.

Compare like artifacts and report a relevant before/after direction: touchpoints,
prereads, duplicated facts, verification cost, or authored maintenance surface.
Keep correctness coverage intact; do not narrow checks or suppress diagnostics
without dependency and behavior evidence.

## Boundaries

- Generated output, catalog volume, source/test companionship, and authored/generated
  boundaries are not avoidable mass by themselves. Respect load-bearing battle,
  persistence, codegen, and measured presentation boundaries.
- Do not introduce routing frameworks or reorganize owners just to improve counts.
  [The documentation map](../README.md) owns policy locality and precedence.
- Unnecessary live/dead paths belong to [06](06_DeadParallelCeremonialSurfaceAudit.md);
  misplaced semantic responsibility belongs to [13](13_StateGravityOwnershipAudit.md).
  Other overlap follows the shared ownership table.
