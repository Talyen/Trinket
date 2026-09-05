---
name: run-audits
description: Execute named Trinket audits or all audits in Docs/Audits, confirm findings, implement bounded fixes, and verify the result. Use when the user requests an audit pass; an uncited audit is not a standing backlog.
---

# Run Trinket audits

Read [the audit policy](../../../Docs/Audits/README.md),
[proposal memory](../../../Docs/Audits/Proposals.md), and each selected audit before
investigating its scope. Read large audit sets incrementally. “All audits” selects
the audit Markdown files directly under `Docs/Audits/`, excluding `README.md` and
`Proposals.md`; linked platform playbooks are separate tasks.

## Confirm and fix

- Establish the baseline and exclusions from proposal memory. Revisit a recorded
  non-finding or rejected proposal only with evidence that supersedes it.
- Inventory evidence once. Prefer scoped searches, existing diagnostics, and reads
  of the suspected owner. A search hit is a candidate, not a finding.
- Apply the selected audit's evidence bar and the shared ownership table. Overlapping
  audits should produce one finding and remedy for the same cause.
- Route confirmed paths through `agent-context.sh`. Choose the complete remedy
  under the audit policy's right-size rules and existing session authorization.
- For multiple fixes, state the implementation order and verification ownership
  before editing. Use an execution plan only when durable coordination is needed.

Zero confirmed findings is a valid outcome. Do not broaden into uncited audits
or edit audit guides to record run history.

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
accepted non-findings, and advancing the completed scope baseline. Check remedies
against [Testing.md](../../../Docs/Platform/Testing.md) and the root change discipline;
a green gate does not justify unnecessary abstractions or tests.

Report fixed findings by audit, zero-finding audits, pending proposals, verification
results, and any skips or blockers. Include change-budget justification when the
routed checks require it; summarize diagnostics instead of pasting logs.
