# Documentation map

One fact has one owner. Link instead of copying policy.

## Layers

| Layer | Where | Role |
|-------|-------|------|
| Human onboarding | [README.md](../README.md), [Scripts/README.md](../Scripts/README.md) | Setup and command index |
| Agent constitution | [AGENTS.md](../AGENTS.md), nested `AGENTS.md` | Guardrails and local hard stops |
| Standing policy | [Platform](Platform/README.md), [Product](Product/Decisions.md) | Architecture, verification, player decisions |
| Path-routed depth | [AgentContext](AgentContext/) ([router](AgentContext/README.md)), package and manifest READMEs, [skills](../.agents/skills/) | Domain exceptions and how-to |
| On demand | [Audits](Audits/README.md), performance/CloudKit playbooks, [Plans](Plans/README.md) | Cited audits, investigation, in-flight plans, and archived plan records |

## Source of truth

| Fact | Owner |
|------|-------|
| Toolchain versions, schemes, entitlements | `project.yml`, `Package.swift`, `Scripts/tool-versions.env` |
| Commands and flags | script usage/option parsing and [Scripts/README.md](../Scripts/README.md) |
| When to run which gate | [Platform/Verification.md](Platform/Verification.md) |
| What a good test is | [Platform/Testing.md](Platform/Testing.md) |
| Module DAG and hub containment | [Platform/Architecture.md](Platform/Architecture.md) (`check-module-boundaries.sh`) |
| Player-facing locked choices | [Product/Decisions.md](Product/Decisions.md) |
| Game surfaces and modes | [Product/Overview.md](Product/Overview.md) |
| Art direction and delivery constraints | [Product/ArtworkStyleGuide.md](Product/ArtworkStyleGuide.md) |
| Cross-package battle / persistence / content | matching [AgentContext](AgentContext/) card |
| Manifest column formats | that manifest directory’s README |
| Package public types / how to extend | that package README |
| Agent workflow and safety hard stops | root and nested `AGENTS.md` |
| Artwork memory budgets (numbers) | [Platform/PerformanceInvestigationPlaybook.md](Platform/PerformanceInvestigationPlaybook.md) Artwork Budgets (enforced by `check-artwork-budget.sh`; `AGENTS.md` holds the one-line hard stop only) |
| Commit format, hooks, and push preconditions | [Platform/Release.md](Platform/Release.md) |
| Audit procedure | [Audits/README.md](Audits/README.md) plus the cited audit file |

Do not restate these elsewhere except a one-line pointer.

## Lifecycle and retention

| Surface | Authority and retention |
|---------|-------------------------|
| Standing Product, Platform, package, and AgentContext docs | Current and authoritative; update with the behavior they describe |
| Skills | Task-specific procedure; use when the trigger applies, with references loaded only for the relevant mode |
| Knowledge | Searchable rationale and rejected approaches; load only by trigger and remove facts already enforced elsewhere |
| Audit guides | Re-runnable procedure, never run history or backlog |
| `Docs/Audits/Proposals.md` | Narrow durable audit memory; evidence pointers must continue to resolve |
| Active execution plans | Temporary, expiring, and allowed only directly under `Docs/Plans/` |
| Completed or cancelled plans | One-line outcome in `Docs/Plans/Archived/README.md`; full execution detail stays in Git history |
| Evals | Representative validation fixtures, not standing workflow policy |

Do not create execution plans under `.agents/` or another parallel plan folder.

## Policy precedence

Within repository guidance, use the canonical owner for the fact in question.
Root `AGENTS.md` sets repository-wide behavior and constraints; a narrower guide
may add constraints but cannot silently relax the root. Product and Platform
documents own standing policy; AgentContext cards and package READMEs supply
scope-specific contracts and procedures.

Checked-in configuration and script option parsing establish what currently
runs. They do not prove that the behavior is intended: a failing script or
misconfigured gate can be a defect. When prose and execution disagree, inspect
the relevant implementation and evidence, then fix the incorrect owner under
the root guide's change discipline. If the intended policy is ambiguous, report
the conflict and obtain that decision rather than silently choosing a side.

## Editing guidance

Add an instruction when it prevents a concrete failure or resolves a recurring
decision. Put it at the narrowest owner that covers its actual scope, state the
trigger and required action, and link to executable mechanics instead of copying
flags or mutable implementation details. Prefer removing a duplicate or stale
rule over adding another exception. Keep rationale and rejected approaches in
knowledge when they remain useful.

For documentation-only changes, verify local links and the routed checks, and
compare command examples or behavioral claims with their executable owners.
A link checker cannot establish that an instruction is correct. For consequential
skill workflow changes, use a relevant scenario from the
[evaluation guide](../.agents/evals/README.md); report the scope of validation
without requiring a separate promotion log or synthetic feature for wording edits.
