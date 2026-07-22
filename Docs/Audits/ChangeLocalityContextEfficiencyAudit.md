# Change Locality & Context Efficiency Audit

**Goal:** Reduce maintenance and agent-context cost by finding recurring changes that require more authored edits, unrelated context, verification, or output than the behavior warrants.

## Intent

Use capped history and task-routing probes to confirm one repeated high-friction cluster. Simplify it through an existing source of truth or owner. A successful fix reduces at least one stable proxy: authored touchpoints, required preread surface, duplicated declarations or policy, routed verification tiers, or routine command output. Do not use tokenizer-specific token counts, and treat a clean pass as valid.

## What counts as locality or context friction

| Tell | Why it is a finding candidate |
|------|-------------------------------|
| One policy or command is maintained in several authored sources | Every change risks drift and consumes repeated context |
| Comparable changes repeatedly co-touch unrelated authored owners | The behavior may lack one source of truth |
| A local path routes unrelated context cards, skills, or verification tiers | Routine work pays avoidable reading or execution cost |
| Routine successful commands emit repetitive output, or failures require opening raw logs | Useful signal is buried in avoidable tool output |
| A frequently changed owner requires unrelated code to understand one concern | The semantic change is not locally reviewable |

**Not this audit:** import legality → the enforced module-boundary gate; wrong semantic ownership → StateGravityOwnershipAudit; local ceremony → InelegantSlopAudit; duplicate UI → DuplicateFeatureSurfaceAudit; unit/UI test runtime and portfolio ownership → UnitTestAudit or E2ETestQualityAudit.

## Hard stops

- Do not weaken, skip, or suppress tests, gates, diagnostics, required prereads, or generated-output checks.
- Do not count intentional source/test, authored/generated-output, manifest/catalog, or implementation/fixture companionship as excess fan-out.
- A broad feature change or large file is not itself a finding. Confirm that unrelated context or touchpoints recur.
- Do not mechanically split files, merge unrelated owners, or centralize distinct policies merely to improve a count.
- Do not add routing metadata, a configuration framework, or an abstraction for an isolated task.

## Confirm before fixing

1. **Recurrence:** show at least three comparable instances, or two with demonstrated drift or an avoidable failure.
2. **Causality:** inspect the relevant diffs, routes, or output; co-change and size alone are not evidence.
3. **Excess surface:** separate necessary behavior, tests, generated output, and verification from the avoidable portion.
4. **Existing home:** identify the executable source of truth, existing semantic owner, or current routing mechanism that should absorb the remedy.
5. **Measurable direction:** state the before/after proxy and show that correctness coverage and required context remain intact.

## Simplification order

1. **Delete** duplicated policy or commands and link consumers to the existing source of truth.
2. **Narrow** existing context classification, verification routing, or bounded output using evidence from representative paths.
3. **Restore** repeated configuration or behavior to its existing semantic owner and remove the old copies.
4. **Move or split** only when it restores an established owner and makes the selected concern independently reviewable; significant moves remain proposals per [README.md](README.md).
5. **Parameterize** only confirmed repetition with at least three current uses; do not create a new routing or metadata system for predicted reuse.

## Domain rules

Executable scripts and checked-in configuration own tool behavior; Platform documents own architecture and testing policy; `AGENTS.md` owns repository-wide guardrails; context cards contain only routed exceptions. Prefer links over copied policy, but keep the minimum local instruction needed to make a routed card actionable.

Mine history only as a capped discovery tool, then confirm the strongest candidates in their diffs. Count authored inputs separately from generated outputs and assets. Verification may narrow only when dependency and behavior evidence proves the removed tier or preread is unrelated. Route the finding to a neighboring audit when locality cost is secondary to that audit's concern.

Every shipped finding must report its before/after proxy and the unchanged correctness signal, such as the same boundary gate, generated-output assertion, compile, or semantic test owner.

## Probe hints

- **Task-Router Relevance:** Run `./Scripts/agent-context.sh --json --paths <representative paths>` for a few comparable recent tasks; compare prereads, context cards, warnings, and verification plans for unrelated routing.
- **Authored Co-Change Clusters:** Use a capped `git log --name-only` or `--stat` sample, excluding generated output and assets; inspect the strongest repeated cluster's diffs before inferring shared ownership.
- **Repeated Policy and Commands:** Search `AGENTS.md`, `Docs/AgentContext/`, `Docs/Platform/`, `Scripts/README.md`, and executable scripts for duplicated rules, versions, flags, or command sequences that can link to one owner.
- **Duplicated Routing Logic:** Compare `agent-context.sh`, `change-classification.sh`, `changed-source-summary.sh`, and `verify-changed.sh`; confirm repeated classifications have one implementation rather than synchronized copies.
- **Output Signal Density:** Inspect routine successful output and bounded failure summaries from verification/CI helpers; prefer existing quiet or summary paths when raw output adds no actionability.
- **Non-Local Review Surface:** For a frequently changed authored owner, inspect whether comparable diffs repeatedly require unrelated sections or files; route genuine ownership drift to StateGravityOwnershipAudit rather than splitting mechanically.
