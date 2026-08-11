# 05. Change Locality & Context Efficiency Audit

**Goal:** Reduce maintenance and agent-context cost by finding recurring changes that require more authored edits, unrelated context, verification, or output than the behavior warrants.

## Intent

Identify repeated high-friction clusters and simplify them through existing sources of truth or owners. A successful fix reduces at least one stable proxy: authored touchpoints, required preread surface, duplicated declarations or policy, routed verification tiers, or routine command output. Do not use tokenizer-specific token counts.

## What counts as locality or context friction

- **Focus:** Co-touch patterns across 3+ files for routine changes, duplicated script logic, bloated guidance cards, and test-suite setup tax.
- **Not this audit:** import legality → the enforced module-boundary gate; live authored mass without locality/routing friction → `02_AuthoredMassGrowthAudit.md`; dual live paths → `08_DualPathRetentionAudit.md`. Full routing: [README.md](README.md) confusable pairs.

## Hard stops

- Do not weaken, skip, or suppress tests, gates, diagnostics, required prereads, or generated-output checks.
- Do not count intentional source/test, authored/generated-output, manifest/catalog, or implementation/fixture companionship as excess fan-out.
- A broad feature change or large file is not itself a finding. Confirm that unrelated context or touchpoints recur.
- Do not mechanically split files, merge unrelated owners, or centralize distinct policies merely to improve a count.
- Do not add routing metadata, a configuration framework, or an abstraction for an isolated task.

## Evidence bar

A finding requires all of:

- **Recurrence or magnitude:** at least three comparable instances; two with demonstrated drift or an avoidable failure; or one measured extreme hotspot that repeatedly forces unrelated owners, prereads, verification tiers, or high-volume diagnostics for a narrow change. Acceptable evidence: version-control co-change history, duplicated policy/command text visible in current sources, routed verification/context output, or friction recorded in prior run handoffs or `Proposals.md`
- **Causality:** co-change and size alone are not evidence — name the shared policy, duplicated command, or missing source of truth that forces the repeated cost
- **Excess surface:** separate necessary behavior, tests, generated output, and verification from the avoidable portion
- **Existing home:** an executable source of truth, semantic owner, or current routing mechanism that should absorb the remedy
- **Measurable direction:** before/after proxy with correctness coverage and required context intact

## Domain rules

Executable scripts and checked-in configuration own tool behavior; Platform documents own architecture and testing policy; `AGENTS.md` owns repository-wide guardrails; context cards, nested guides, skills, and audits contain only routed exceptions or distinct scope — not restated root policy. Prefer links over copied policy, but keep the minimum local instruction needed to make a routed card actionable. Guidance-surface findings succeed when duplicated policy collapses to one owner and required preread shrinks. When one source-of-truth problem is confirmed, update the complete authored cluster—scripts, configuration, routing, docs, and diagnostics contracts—needed to remove the duplication without weakening a gate.

Count authored inputs separately from generated outputs and assets. Verification may narrow only when dependency and behavior evidence proves the removed tier or preread is unrelated. Route the finding to a neighboring audit when locality cost is secondary to that audit's concern.

Every shipped finding must report its before/after proxy and the unchanged correctness signal (same boundary gate, generated-output assertion, compile, or semantic test owner).
