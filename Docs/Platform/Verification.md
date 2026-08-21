# Verification and CI

This guide owns when to choose a verification route, gate composition, test
tiers, and style ownership. Exact commands and flags live in
[`Scripts/README.md`](../../Scripts/README.md) and each script's `--help`.
Test authoring conventions live in [Testing.md](Testing.md). Isolation and IDE
setup: [SimulatorOperations.md](SimulatorOperations.md).

## Confidence ladder

Choose the cheapest route that answers the question at hand.

| Level | Command | Use |
|---|---|---|
| Focused iteration | Package/test script | Fast feedback on the current owner |
| Task handoff | `handoff.sh` | Required path-scoped agent gate |
| Gate only | `ci-gate.sh` | Generation, style, boundaries, scripts, and release metadata; no unit/UI |
| Local canary | `test-deploy.sh --mode smoke` | Gate, unit, and smoke |
| Deploy confidence | `test-deploy.sh` | Gate, unit, and full UI |
| Main CI | Shared `tests.yml` workflow | Post-push on `main` (no pull-request workflow): gate, build once, unit, full smoke, and sharded exhaustive UI |
| Local integration / performance | `test.sh ui` / `performance.sh` | Ad hoc; not part of any GitHub workflow |

Run `./Scripts/agent-context.sh --agent --paths <files...>` after touched paths
are known. Use `--working-tree` only for an intentional whole-tree scope. The
briefing prints the required/optional read contract and applicable handoff
route; rerun it when scope crosses into another owner.

## Test tiers

| Tier | Command | Notes |
|---|---|---|
| Package unit | `test-package.sh` | Cheapest package-owned behavior check |
| All unit | `test.sh unit` | All package schemes; no app-level unit target |
| App-only build | `test.sh unit --app-only` | Compile coverage for app-level Swift changes |
| Targeted smoke | `test.sh smoke` with a class filter | One smoke-plan invocation |
| Smoke | `test.sh smoke` | The checked-in smoke plan; CI runs the same registry |
| Targeted / full UI | `test.sh ui` | Focused iteration or explicit full confidence |
| Performance | `performance.sh` | Ad hoc investigation; not a CI job |

After a green isolated rebuild, `--no-build` is appropriate for mid-task smoke
reruns in the same slot. Final handoff still uses the full isolated route.

`handoff.sh` is the canonical path-scoped route. It composes generation,
style, package, compile, smoke, and idempotence checks from the changed paths;
the script's help and `agent-context.sh` output show the exact route. Final
plan cleanup is checked with `--final`.

## Gate composition

| Gate | Composition |
|---|---|
| `ci-gate.sh` | Generate/assert against HEAD, full-tree style, module boundaries, script syntax and regression tests, Swift Testing policy, release-note validation |
| `ci-assets-gate.sh` | Generate assets, assert, regenerate in a stable locale, assert again |
| `test-deploy.sh` | `ci-gate.sh`, unit, then full UI or smoke |
| Main CI | Post-push on `main`: gate, one build-for-testing, parallel unit/full-smoke/exhaustive-UI jobs |

The shared build job produces test products for fan-out. Package unit schemes
remain on the unit job. `check-build-cache-paths.sh` keeps local no-build
freshness inputs aligned with the CI cache key.

## Style and boundary ownership

| Check | Owns |
|---|---|
| SwiftFormat | Mechanical Swift formatting and preferred rewrites |
| SwiftLint | API idioms, semantics, size, and unsafe operations |
| `check-ui-style.sh` | Product colors, materials, and chrome routed through `TrinketDesign` |
| `check-platform-api-bans.sh` | Repository-banned legacy observation/navigation APIs |
| `check-exclusivity-footguns.sh` | Suspicious `inout` access to stored properties |
| `check-module-boundaries.sh` | Package layering and imports |

`Color.primary`, `.secondary`, and `.clear` remain valid adaptive primitives.
Feature-specific product colors and visual effects go through the design system;
use allow comments only for narrow, explained exceptions.

## Failures and reporting

Read structured invocation reports before raw build logs. Use
`./Scripts/ci-diagnostics.sh <results-dir>` to aggregate them and follow
[CI diagnostics](../AgentContext/ci-diagnostics.md) for classification and
escalation. Never kill foreign Xcode or Simulator processes.

The push gate may print an advisory change-budget report. Warnings do not fail
the task, but unusual production/test surface growth needs a necessity statement
and the simpler alternative that was rejected. Timing logs are diagnostic data,
not a routine optimization mandate.

Before a requested push, run `agent-push-gate.sh` after committing. It checks
generation completeness only; the path-scoped handoff remains the pre-CI source
gate.

Land on `main` by direct push; do not open pull requests. After a red CI run,
triage with `./Scripts/ci-diagnostics.sh` and
[ci-diagnostics.md](../AgentContext/ci-diagnostics.md); do not invent a separate
fixer playbook. Do not require `tests / CI OK` as a GitHub push gate on `main`.
