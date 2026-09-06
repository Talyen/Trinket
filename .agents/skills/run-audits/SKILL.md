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

## Confirm and fix

- Use the selected concern's whole scope by default, prioritizing risk. Restrict to
  changed code only when requested, establishing and reporting the comparison range
  under the audit policy. Proposal memory is not a coverage baseline.
- Check relevant prior decisions and exceptions; revisit them when new evidence or
  changed assumptions supersede the recorded reason.
- Develop candidates from consequential flows and boundaries; no pre-existing finding
  is needed. Choose scoped probes and read relevant owners without repeating orientation.
  Confirm intended behavior and impact before treating a signal as a finding.
- Apply the selected audit's evidence bar and the shared ownership table. Overlapping
  audits should produce one finding and remedy for the same cause.
- Route confirmed paths through `agent-context.sh`. Choose the complete remedy
  under the audit policy's right-size rules and existing session authorization.
- For multiple fixes, state the implementation order and verification ownership
  before editing. Use an execution plan only when durable coordination is needed.

Defer only approval-sensitive work; continue independent authorized findings.
Follow the audit policy for zero-finding results and cross-owner remedies. Do not
edit audit guides to record run history.

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

Use [the audit policy](../../../Docs/Audits/README.md) for proposal recording,
accepted non-findings, and actual review coverage. Check remedies against [Testing.md](../../../Docs/Platform/Testing.md) and the root change discipline;
a green gate does not justify unnecessary abstractions or tests.

Report fixed findings by audit, zero-finding audits, pending proposals, verification
results, actual scope (including any incremental range), and any skips or blockers.
Distinguish source confirmation from runtime validation; a guide review is not a
completed product-code audit. Include change-budget justification when the
routed checks require it; summarize diagnostics instead of pasting logs.
