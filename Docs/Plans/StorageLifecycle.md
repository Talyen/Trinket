---
type: execution-plan
status: active
created: 2026-10-27
updated: 2026-10-27
expires: 2026-11-10
---

# Storage lifecycle

## Objective and boundaries

Finish safe storage cleanup without deleting active or unknown work, unique
retained evidence, artwork masters, release archives, symbols or provenance.
Pushes and player-resource changes remain outside this task.

## Remaining protected state

- [ ] Recheck build 42's duplicate working files after the 24-hour grace period
  following its receipt update. Its existing archive, IPA and symbols were verified
  and linked to the receipt; Apple reported no matching build for the current
  marketing version. Preserve the backup and receipt regardless of cleanup.
- [ ] Preserve the 29 created-stage build-number reservations. None records an
  archive or IPA; build 49 also retains an archive result. Missing command logs
  prevent determining all outcomes from local evidence. Build 44 has no located
  local archive backup, but Apple's read-only check reports its symbols present.
  Four other ready builds now link to verified existing local backups.
- [ ] Assess old integrated worktrees only when their owners have finished and
  inactivity is provable. A clean tree and ancestor relationship do not establish
  that a retained checkout is no longer needed; do not poll or alter other chats.
- [ ] Revisit eligible duplicate evidence after its retention window and once no
  active or explicitly kept owner remains. Byte equality alone does not establish
  physical savings or authorize deletion of unique evidence.

Use [the isolated workflow](../../AGENTS.md#route-and-read),
[output retention](../../Scripts/Reference.md#output-retention) and
[verification policy](../Platform/Verification.md). Retain this plan until the
remaining ownership and release-state questions are resolved.
