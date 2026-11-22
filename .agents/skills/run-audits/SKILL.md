---
name: run-audits
description: Execute named Trinket audits or all audits in Docs/Audits, confirm findings, implement bounded fixes, and verify the result. Use when the user requests a codebase audit pass, not merely a review or edit of audit instructions.
---

# Run Trinket audits

Start with [the audit policy](../../../Docs/Audits/README.md),
[proposal memory](../../../Docs/Audits/Proposals.md), and each selected audit
guide (reading large audit sets incrementally). "All audits" refers to the
numbered guides in [the ownership table](../../../Docs/Audits/README.md#ownership),
excluding `README.md`, `Proposals.md`, and the linked playbook row.

## Running the pass

- Follow [the audit policy](../../../Docs/Audits/README.md) for sizing, approval
  boundaries, proposal memory, and reporting.
- Route confirmed target paths through
  `python3 Scripts/agent-brief.py --status --read --paths <files...>` before
  editing; add a durable plan only if resumption needs one.
- For larger passes with independent confirmed fixes, subagents can save time:
  give each worker a self-contained brief (finding, evidence, disjoint file
  ownership, intended fix, focused check) and run the integrated handoff once
  across all changed paths at the end rather than duplicating it per worker.
  Small or tightly coupled passes are usually faster to handle directly.

## Closing the pass

Review the integrated diff and report outcomes per
[Verification and handoff](../../../Docs/Audits/README.md#verification-and-handoff).
