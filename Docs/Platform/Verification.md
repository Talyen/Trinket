# Verification and CI

This guide owns task-to-script routing, gate composition, test tiers, and style
ownership. Test authoring conventions live in [Testing.md](Testing.md).
`Scripts/README.md` is the command index; checked-in scripts are the source of
truth when flags change. Isolation and IDE setup: [SimulatorOperations.md](SimulatorOperations.md).

## Confidence ladder

Choose the cheapest route that answers the question at hand.

| Level | Command | Use |
|---|---|---|
| Focused iteration | `test-package.sh <Package>` or `test.sh <mode> <Class>` | Fast feedback on the current owner |
| Task handoff | `handoff.sh --isolate --paths …` | Required path-scoped agent gate |
| Gate only | `ci-gate.sh` | Generation, style, boundaries, scripts, and release metadata; no unit/UI |
| Local canary | `test-deploy.sh --mode smoke` | Gate, unit, and quick smoke |
| Deploy confidence | `test-deploy.sh` | Gate, unit, and full UI |
| PR/main CI | Shared `tests.yml` workflow | Gate, build once, unit, full smoke, and sharded exhaustive UI |
| Nightly | `nightly.yml` | Integration and Battle performance calibration |

Run `./Scripts/agent-context.sh --agent --paths <files...>` after touched paths
are known. It discovers nested guides and prints the applicable handoff route.
Rerun it when scope crosses into another area.

## Test tiers

| Tier | Command | Notes |
|---|---|---|
| Package unit | `test-package.sh <Package>` | Cheapest package-owned behavior check |
| All unit | `test.sh unit` | All package schemes; app test target has no app-level unit cases |
| App-only build | `test.sh unit --app-only` | App compile coverage for app-level Swift changes |
| Targeted smoke | `test.sh smoke <Class...>` | One invocation using `Smoke.xctestplan` filters |
| Quick smoke | `test.sh smoke` | Homestead canary from `QuickSmoke.xctestplan` |
| Full smoke | `test.sh smoke-full` | The complete six-surface smoke plan; CI/PR ownership |
| Targeted UI | `test.sh ui <Class>` | Focused exhaustive UI iteration |
| Full UI | `test.sh ui` | Explicit local confidence and CI sharding |
| Integration | `test.sh all` | Nightly/manual |
| Performance | `performance.sh` | Exclusive, comparable Battle scenarios |

After a green isolated rebuild, `--no-build` is appropriate for mid-task smoke
reruns in the same slot. Final handoff still uses the full isolated route.

`handoff.sh` formats only touched Swift files, tests touched packages, selects a
targeted smoke owner when one exists, and otherwise fills compile coverage with
an app build. It then verifies generated output is idempotent. Metrics, copy,
layout, and symbol changes are not automatically demoted.

## Gate composition

| Gate | Composition |
|---|---|
| `ci-gate.sh` | Generate/assert against HEAD, full-tree style, module boundaries, script syntax and regression tests, Swift Testing policy, release-note validation |
| `ci-assets-gate.sh` | Generate assets, assert, regenerate in a stable locale, assert again |
| `test-deploy.sh` | `ci-gate.sh`, unit, then full UI or quick smoke |
| PR/main | Gate, one build-for-testing, parallel unit/full-smoke/exhaustive-UI jobs |

The shared build job produces test products for fan-out. Package unit schemes
remain on the unit job. Nightly restores caches but does not own cache writes.
`check-build-cache-paths.sh` keeps local no-build freshness inputs aligned with
the CI cache key.

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

Every completed handoff and push gate prints an advisory change-budget report.
Warnings do not fail the task, but unusual production/test surface growth needs
a necessity statement and the simpler alternative that was rejected. Timing
logs are diagnostic data, not a routine optimization mandate.

Before a requested push, run `agent-push-gate.sh` after committing. It checks
generation completeness only; the path-scoped handoff remains the pre-CI source
gate.

Merging a PR into `main` requires the GitHub `tests / CI OK` check. That check is
not a push gate on `main`. After a red CI run, triage with
`./Scripts/ci-diagnostics.sh` and [ci-diagnostics.md](../AgentContext/ci-diagnostics.md);
do not invent a separate fixer playbook.
