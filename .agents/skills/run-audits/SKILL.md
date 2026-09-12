---
name: run-audits
description: Execute named Trinket audits or all audits in Docs/Audits, confirm findings, implement bounded fixes, and verify the result. Use when the user requests a codebase audit pass, not merely a review or edit of audit instructions.
---

# Run Trinket audits

Read [the audit policy](../../../Docs/Audits/README.md),
[proposal memory](../../../Docs/Audits/Proposals.md), and each selected audit before
investigating its scope. Read large audit sets incrementally. “All audits” selects
the audit Markdown files directly under `Docs/Audits/`, excluding `README.md` and
`Proposals.md`; linked platform playbooks are separate tasks.

## Coordinate the pass

Use [the audit policy](../../../Docs/Audits/README.md) for discovery, evidence,
sizing, approval boundaries, proposal memory, and reporting. Route confirmed paths
through `agent-context.sh` and state implementation order and verification ownership
before editing multiple fixes. Use a durable plan only when coordination or
resumption needs one.

## Parallel work when useful

Use subagents for confirmed, independent fixes when that saves meaningful time.
Keep a small or tightly coupled pass in the root. Do not delegate repeated repository
orientation or speculative sweeps.

Give each agent the finding, confirming evidence, exact file or symbol ownership,
applicable repository guidance, intended remedy, and focused verification. Use the
smallest context that makes the brief self-contained; let the available tool and
configuration determine model and role settings unless the user specifies them.
Agents share files, so assign disjoint writes and preserve unrelated work.

The root reviews each diff against the evidence and integrates overlaps. Workers
run focused checks; the root runs the required integrated handoff once for the
union of changed and deleted paths. Do not duplicate the full gate across workers.

## Close the pass

Review the integrated changes and report the outcomes required by
[Verification and handoff](../../../Docs/Audits/README.md#verification-and-handoff).
A guide review is not a completed product-code audit.
