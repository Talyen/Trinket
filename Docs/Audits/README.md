# Audits

Re-runnable guides for coding agents to improve codebase quality and fix issues.
Run the audits the user requests; uncited guides are not a standing backlog.
Reviewing these instructions does not itself request a product-code audit.
Numbers and filenames are stable identifiers; retired numbers 05, 08, and 11 stay retired.

## Shared contract

A finding needs confirming evidence, player or maintenance impact, a remedy that
addresses the cause, and matching verification. Source proof, a reproduction,
a diagnostic, or measured maintenance cost can establish evidence; a search hit
alone cannot. Syntax, size, similarity, and absence of a particular implementation
pattern are candidate signals, not findings. **Zero findings is a successful audit result.**

Explain meaningful structural tradeoffs and expected surface/cost direction when
choosing a consequential refactor. Routine fixes do not need an alternatives essay
or LOC forecast. Prefer deletion, reuse, and simplification when they solve the
problem; an abstraction or lower line count is not an outcome by itself.

### Scope and discovery

By default, review the selected audit's whole concern across relevant authored
owners. Prioritize consequential player flows, fragile boundaries, known failure
modes, and maintenance hotspots; agents choose their probes. No pre-existing bug
candidate is required. Whole-concern scope does not require reading every file or
running every test. Report what was examined and material gaps in coverage.

Use changed-code-only scope when requested. Establish the comparison range from
the request or reliable evidence of the last completed review of that same concern;
include applicable uncommitted changes and affected owners. If no reliable range
exists, ask for it or disclose that incremental coverage cannot be established.
Do not invent a baseline or reuse another audit's completion as coverage.
Record the range and exclusions in the handoff, not a shared baseline table.

### Evidence cone and bounded breadth

Follow a candidate through callers, implementations, tests, authored configuration,
manifest inputs, and documentation far enough to establish intended behavior and
root cause. Once confirmed, inspect materially similar instances under the same
invariant and fix the confirmed cluster when verification is bounded. Do not leave
an adjacent manifestation or replaced path behind merely to minimize the diff.

Cross-audit routing deduplicates reporting; it does not prohibit necessary root-cause
work. Use the most specific concern in the ownership table and report one finding
per cause. A fix may cross owners without launching an uncited audit's full inventory.

### Severity scale

Assign severity by demonstrated impact and reachability, not by syntax or audit name.

| Sev | Meaning |
|-----|---------|
| P0 | Critical: reachable loss/corruption of player progress, widespread crash, or inability to play without a viable recovery |
| P1 | High: consequential wrong behavior, broken player flow, or recurring failure that blocks development or verification |
| P2 | Material, bounded improvement: degraded interaction, maintainability cost, test signal/reliability gap, or limited policy violation |
| P3 | Minor consistency or style; optional when trivial or already touching the surface |

An enforced gate failure must be resolved or reported under
[Verification.md](../Platform/Verification.md), but is not automatically P0.
A source-proven hazard need not be reproduced in production; explain the reachable
failure and its impact. Do not inflate maintenance findings to justify action.

### Right-size policy

Choose the smallest coherent remedy that fully removes the cause and fits the
existing architecture. Preserve intentional game behavior and live compatibility.
Follow [the root change policy](../../AGENTS.md#choose-the-change) for dependencies,
architectural changes, and approval boundaries.

- **Fix in-pass:** confirmed, reversible changes with clear intent and bounded
  verification, including affected callers and removal of replaced implementations.
- **Propose the sensitive portion:** unresolved product policy, live compatibility
  migrations, new architectural boundaries/dependencies, or broad/high-risk rewrites.
  Explain the evidence, benefit, intended owner, removal/migration boundary, and
  why a smaller remedy is insufficient. Record unresolved decisions in
  [Proposals.md](Proposals.md); continue independent authorized work. Existing session
  authorization applies; do not ask again for an already approved decision.

For multiple fixes, state implementation order and verification ownership before
editing. Use a durable execution plan only when coordination/resumption needs one,
following [Plans](../Plans/README.md).

### Run memory

[Proposals.md](Proposals.md) holds unresolved decisions, rejected proposals, and
intentional non-findings with evidence pointers and reasons. Check relevant entries
before re-proposing work; reassess when new evidence or changed assumptions supersede
the reason. It is neither run history nor proof that an audit's scope was reviewed.
Outcomes, coverage, and unresolved candidates belong in the handoff; do not append
run logs or Done tables to audit guides.

### Code and test budgets

Judge simplification by avoided maintenance, indirection, duplication, or executed
work, not just authored LOC. Ownership/correctness repairs may grow when necessary.
Explain routed change-budget warnings and the simpler rejected alternative under
[AGENTS.md](../../AGENTS.md). Do not preserve redundant paths to avoid migration work.

Verification does not require new tests. Use the coverage decision and semantic
owners in [Testing.md](../Platform/Testing.md); preserve distinct consequential
coverage and remove tests made redundant. Parameterization alone does not reduce
expanded executions or prove that cases are interchangeable.

### Verification and handoff

Use the path-scoped route in [Verification.md](../Platform/Verification.md):
`./Scripts/handoff.sh --isolate --paths <changed files>` for the union of fixes.
Report findings/fixes, proposals, actual review coverage, zero-finding audits, and
exact verification skips or blockers. Missing toolchains do not invalidate source
findings, but do not claim runtime validation or required-check completion without it.

Multi-audit execution and integration:
[run-audits skill](../../.agents/skills/run-audits/SKILL.md).

### Audit template

Keep each guide focused on its goal, domain invariants and intentional exceptions,
what evidence confirms a problem, and what a successful remedy preserves/improves.
Optional examples illustrate defect classes, not mandatory search recipes or quotas.
Link shared policy here and domain policy to its canonical owner. Add discovery or
remediation details only when they prevent a domain-specific mistake.

## Ownership

| # | Owner audit | Concern |
|---|-------------|---------|
| 01 | [01_AppleNativeUIAudit.md](01_AppleNativeUIAudit.md) | Native layout, typography, and adaptation quality |
| 02 | [02_MaintenanceSurfaceLocalityAudit.md](02_MaintenanceSurfaceLocalityAudit.md) | Authored maintenance mass, locality, guidance, verification, and context cost (retrospective) |
| 03 | [03_BehaviorHardeningAudit.md](03_BehaviorHardeningAudit.md) | Durable progress, transactions, recovery, and synchronization |
| 04 | [04_BugHuntingAudit.md](04_BugHuntingAudit.md) | Risk-led correctness investigation |
| 06 | [06_DeadParallelCeremonialSurfaceAudit.md](06_DeadParallelCeremonialSurfaceAudit.md) | Dead, parallel/compatibility, and ceremonial authored surface |
| 07 | [07_DocumentationStalenessAudit.md](07_DocumentationStalenessAudit.md) | Doc drift |
| 09 | [09_DuplicateFeatureSurfaceAudit.md](09_DuplicateFeatureSurfaceAudit.md) | Copy-paste feature screens / shells |
| 10 | [10_E2ETestQualityAudit.md](10_E2ETestQualityAudit.md) | UI / smoke / exhaustive test quality |
| 12 | [12_SideEffectSurfaceAudit.md](12_SideEffectSurfaceAudit.md) | Effect ownership, determinism, and lifecycle |
| 13 | [13_StateGravityOwnershipAudit.md](13_StateGravityOwnershipAudit.md) | Misplaced logic in AppState / hubs / mega-views |
| 14 | [14_SwiftConcurrencyDataRaceAudit.md](14_SwiftConcurrencyDataRaceAudit.md) | Concurrency / Sendable |
| 15 | [15_TypeSafetyAudit.md](15_TypeSafetyAudit.md) | Unsafe conversions and invalid domain representations |
| 16 | [16_UIInteractionFeedbackAudit.md](16_UIInteractionFeedbackAudit.md) | Usable interaction, feedback, and basic accessibility semantics |
| 17 | [17_UnitTestAudit.md](17_UnitTestAudit.md) | Unit/package test value, runtime, redundancy, fixture sprawl, and tier ownership |
| — | [PerformanceInvestigationPlaybook.md](../Platform/PerformanceInvestigationPlaybook.md) | Device-led performance investigation |

Ownership determines where a finding is reported and deduplicated. It does not require leaving necessary callers, tests, configuration, docs, or adjacent symptoms unchanged when they belong to the same root-cause remedy.

### Confusable pairs

Use this table to route confirmed findings, not to classify search hits as defects.
Guides link their closest neighbors; one problem produces one finding under one owner.

| If the hit is… | Owner |
|----------------|-------|
| Proven dead surface or unnecessary parallel/ceremonial responsibility in the correct owner | [06_DeadParallelCeremonialSurfaceAudit.md](06_DeadParallelCeremonialSurfaceAudit.md) |
| Wrong semantic owner, with or without a leftover twin | [13_StateGravityOwnershipAudit.md](13_StateGravityOwnershipAudit.md) (move, then delete the old path) |
| Demonstrated avoidable context/change cost from mixed jobs or duplicated facts | [02_MaintenanceSurfaceLocalityAudit.md](02_MaintenanceSurfaceLocalityAudit.md) |
| Repeated product presentation with demonstrated maintenance cost or divergent behavior | [09_DuplicateFeatureSurfaceAudit.md](09_DuplicateFeatureSurfaceAudit.md) |
| Confirmed native layout/typography or adaptation defect without a structural twin | [01_AppleNativeUIAudit.md](01_AppleNativeUIAudit.md) |
| Duplicate, weak, or over-expanded test coverage | [17_UnitTestAudit.md](17_UnitTestAudit.md) (unit/package) or [10_E2ETestQualityAudit.md](10_E2ETestQualityAudit.md) (UI tiers) |
| Durable transaction/recovery failure; use 13 when misplaced authority is the confirmed root cause | [03_BehaviorHardeningAudit.md](03_BehaviorHardeningAudit.md) |
| Actor isolation, reentrancy, or concurrent task-lifetime failure | [14_SwiftConcurrencyDataRaceAudit.md](14_SwiftConcurrencyDataRaceAudit.md) |
| Reachable invalid representation or unsafe conversion | [15_TypeSafetyAudit.md](15_TypeSafetyAudit.md) |
| Unusable control/navigation behavior without a persistence failure | [16_UIInteractionFeedbackAudit.md](16_UIInteractionFeedbackAudit.md) |
| Effect whose placement or lifecycle violates its owning contract | [12_SideEffectSurfaceAudit.md](12_SideEffectSurfaceAudit.md) |

Package/layer imports are continuously enforced by [Architecture.md](../Platform/Architecture.md) and `./Scripts/check-module-boundaries.sh`; they are not a user-invoked audit.

Standing conventions: [Testing.md](../Platform/Testing.md), [Architecture.md](../Platform/Architecture.md), `AGENTS.md`. CloudKit release steps: [CloudKitPreShipChecklist.md](../Platform/CloudKitPreShipChecklist.md).
