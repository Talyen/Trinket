# Documentation map

One fact has one owner. Link instead of copying policy.

## Layers

| Layer | Where | Role |
|-------|-------|------|
| Human onboarding | [README.md](../README.md), [Scripts/README.md](../Scripts/README.md) | Setup and command index |
| Agent constitution | [AGENTS.md](../AGENTS.md), nested `AGENTS.md` | Guardrails and local hard stops |
| Standing policy | [Platform](Platform/README.md), [Product](Product/Decisions.md) | Architecture, verification, player decisions |
| Path-routed depth | [AgentContext](AgentContext/), package and manifest READMEs, [Skills](Skills/apple-design/SKILL.md) | Domain exceptions and how-to |
| On demand | [Audits](Audits/README.md), performance/CloudKit playbooks, [Plans](Plans/README.md) | Cited audits, investigation, in-flight plans, and archived plan records |

## Source of truth

| Fact | Owner |
|------|-------|
| Toolchain versions, schemes, entitlements | `project.yml`, `Package.swift`, `Scripts/tool-versions.env` |
| Commands and flags | script `--help` and [Scripts/README.md](../Scripts/README.md) |
| When to run which gate | [Platform/Verification.md](Platform/Verification.md) |
| What a good test is | [Platform/Testing.md](Platform/Testing.md) |
| Module DAG and hub containment | [Platform/Architecture.md](Platform/Architecture.md) (`check-module-boundaries.sh`) |
| Player-facing locked choices | [Product/Decisions.md](Product/Decisions.md) |
| Cross-package battle / persistence / content | matching [AgentContext](AgentContext/) card |
| Manifest column formats | that manifest directory’s README |
| Package public types / how to extend | that package README |
| Agent hard stops | root and nested `AGENTS.md` only |
| Audit procedure | [Audits/README.md](Audits/README.md) plus the cited audit file |

Do not restate these elsewhere except a one-line pointer.
