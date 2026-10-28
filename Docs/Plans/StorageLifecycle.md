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

## Completed locally

- Final integration preserves deliverables and removes its checkout when idle;
  `--keep-worktree` retains intermediate work. Unknown ignored files or active
  processes stop removal. Verified task-owned Git monitors stop through Git.
- Evidence snapshots record hashes and clone verified unchanged files when possible.
  Bounded compaction resumes between passes and does not convert native bundles.
- Simulator, UI, build and device producers record their checkout and explicit
  output paths when possible. Scoped cleanup rechecks owner identity and serializes
  final removal with producer lease acquisition. Legacy, malformed, uninspectable
  or retargeted-path leases remain global. TestFlight keeps its deployment lock.
- A read-only audit classified 64,226 evidence files and compared duplicate bytes;
  11,849 groups contained approximately 8.10 billion duplicate logical bytes.
  Shared APFS extents, open-file ownership and metadata were not measured. Nearly
  all duplicate members were recent or in registered worktrees; unique evidence
  and keep markers were preserved. The full JSON and cleanup decisions are in the
  retained `codex/storage-audit-scoping` task evidence.
- Guarded cleanup removed six independently verified TestFlight working copies,
  3,292,307,456 reported allocated bytes. Both authoritative backups and receipts
  were reverified after removal. Volume free space rose by 3,996,434,432 bytes
  during the observation window; other host activity makes attribution uncertain.

## Remaining protected state

- [ ] Review the 29 unfinished or unknown deployment receipts when their owners or
  state can be established. Build 42 is exported but has no registered authoritative
  backup; retain its archive, IPA and inspection data. Do not replace unique evidence.
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
