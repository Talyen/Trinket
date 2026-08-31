# Documentation map

One fact has one owner. Link instead of copying policy.

## Layers

| Layer | Where | Role |
|-------|-------|------|
| Human onboarding | [README.md](../README.md), [Scripts/README.md](../Scripts/README.md) | Setup and command index |
| Agent constitution | [AGENTS.md](../AGENTS.md), nested `AGENTS.md` | Guardrails and local hard stops |
| Standing policy | [Platform](Platform/README.md), [Product](Product/Decisions.md) | Architecture, verification, player decisions |
| Path-routed depth | [AgentContext](AgentContext/), package and manifest READMEs, [Skills](../.agents/skills/apple-design/SKILL.md) | Domain exceptions and how-to |
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
| Cross-package battle / persistence / content | matching [AgentContext](AgentContext/) card |
| Manifest column formats | that manifest directory’s README |
| Package public types / how to extend | that package README |
| Agent workflow and safety hard stops | root and nested `AGENTS.md` |
| Artwork memory budgets | [Platform/PerformanceInvestigationPlaybook.md](Platform/PerformanceInvestigationPlaybook.md) Artwork Budgets + `AGENTS.md` guardrail (enforced by `check-artwork-budget.sh`) |
| Audit procedure | [Audits/README.md](Audits/README.md) plus the cited audit file |

Do not restate these elsewhere except a one-line pointer.

## Policy precedence

When guidance overlaps, use the narrowest applicable owner. Root `AGENTS.md`
sets repository-wide agent behavior and safety; nested `AGENTS.md` files add
path-local hard stops. Product and Platform documents define standing product
and engineering policy. AgentContext cards and package READMEs define the
current ownership and implementation contract for their scope. Checked-in
configuration and enforcement scripts are authoritative for executable
mechanics; update the owning prose when those mechanics change.
