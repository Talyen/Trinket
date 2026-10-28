---
type: execution-plan
status: active
created: 2026-10-27
updated: 2026-10-27
expires: 2026-11-10
---

# Storage lifecycle

## Objective and boundaries

Complete the storage workflow requested in this task without deleting active or
unknown work, unique evidence, artwork masters, release archives, symbols or
provenance. Pushes and player-resource changes remain outside this task.

## Completed locally

- Final integration removes its checkout after preserving evidence; explicit
  `--keep-worktree` retains intermediate work. Unknown ignored files stop automatic
  removal and a failed cleanup does not undo landing.
- New evidence manifests record hashes and unchanged files may clone prior verified
  snapshot bytes. Bounded evidence compaction resumes across invocations and may
  clone exact native-bundle files without changing their contents or paths.
- A read-only storage report summarizes worktrees, evidence, derived data and
  protected cleanup decisions. Guarded cleanup and compaction were run; the live
  lease and unknown or explicitly kept items remained protected.
- A recursive comparison of two `tech-stack-improvements` soak result snapshots
  found only a different `.DS_Store`; that is one sample, not a complete duplicate
  inventory or evidence that the underlying APFS blocks are independent.

## Remaining work

- [ ] Establish resource-specific ownership for every simulator, UI, build and
  release producer before narrowing broad lease protection. Existing lease slots
  record process identity but not authoritative output roots; `DERIVED_DATA_PATH`
  can be overridden. Unknown and legacy leases must continue to fail closed, and
  a new owner must not race the final removal check. Validate concurrent producers,
  open files, stale markers, custom paths and failed process inspection.
- [ ] Re-run release duplicate inventory after active leases finish. Inspect old
  unfinished or unknown release receipts and retain authoritative archives,
  matching symbols and unique evidence. Review exact unique-evidence batches
  before changing their retention; do not infer disposability from age.
- [ ] Extend the read-only evidence inventory to classify artifact types and
  identify byte-verified duplicate groups and their protection reasons. The
  current report supplies task-level sizes, not a complete duplicate audit.
- [ ] Assess integrated old worktrees individually when inactivity and ownership
  are provable; clean Git status alone is insufficient. Preserve other chats and
  ignored work. Re-run inventory and measure actual free-space changes.

Use [the isolated workflow](../../AGENTS.md#route-and-read),
[output retention](../../Scripts/Reference.md#output-retention) and
[verification policy](../Platform/Verification.md). Retain this plan until its
remaining ownership and cleanup work is finished.
