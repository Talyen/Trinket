# Verification and CI

This guide owns when to choose a verification route, gate composition, test
tiers, and style ownership. Exact commands and flags live in
[`Scripts/README.md`](../../Scripts/README.md) and each script's usage/option parsing.
Test authoring conventions live in [Testing.md](Testing.md). Isolation and IDE
setup: [SimulatorOperations.md](SimulatorOperations.md).

## Confidence ladder

Choose the cheapest route that answers the question at hand.

| Level | Command | Use |
|---|---|---|
| Focused iteration | Package/test script | Fast feedback on the current owner |
| Task handoff | `handoff.sh` | Required path-scoped agent gate |
| Gate only | `ci-gate.sh` | Generation, style, boundaries, scripts, and release metadata; no unit/UI |
| Fast gate | `ci-gate.sh --fast` | Cheap full-tree slices only (boundaries, Swift Testing, release notes) |
| Local canary | `test-deploy.sh --mode smoke` | Optional human confidence: gate, unit, and smoke |
| Release confidence | `release.sh` / `test-deploy.sh` | Pre-release only: gate, unit, and full UI (the one sanctioned local full-UI run) |
| Main CI | Shared `tests.yml` workflow | Post-push on `main` (no pull-request workflow): gate, build once, unit, full smoke, and sharded exhaustive UI |
| Local debugging / performance | `test.sh ui <Target>` / `performance.sh` | Single UI target or ad hoc performance; the full exhaustive suite is CI-owned |

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
| Targeted UI | `test.sh ui <Target>` | Single-target debugging of a CI-owned shard |
| Full UI | `TRINKET_ALLOW_FULL_UI=1 test.sh ui` or `test-deploy.sh` | Opt-in only; CI owns the suite post-push, releases run it via deploy verification |
| Performance | `performance.sh` | Ad hoc investigation; not a CI job |

## Local simulator budget

Full smoke and exhaustive UI are CI-owned post-push gates; watch them with
`agent-watch-ci.sh` instead of pre-running them. Locally:

- Unit tests always; they catch the routine regressions in seconds.
- During UI iteration, run the routed targeted smoke class (`test.sh smoke <Class>`).
- Debug at most one exhaustive target (`test.sh ui <Class>`) when touching its feature area.
- Bare full-suite UI is refused locally unless `TRINKET_ALLOW_FULL_UI=1`; routine development never sets it.
- The full local UI run belongs to pre-release deploy verification (`release.sh` / `test-deploy.sh`).

After a green isolated rebuild, `--no-build` is appropriate for mid-task smoke
reruns in the same slot. Final handoff still uses the full isolated route.

`handoff.sh` is the canonical path-scoped route. It composes generation,
style, package, compile, smoke, documentation, and idempotence checks from the
changed paths; the script's help and `agent-context.sh` output show the exact
route. Docs and Markdown edits route `check-docs.py`. `--final` is only for
plan-lifecycle cleanup. After the routed plan succeeds, handoff always runs
the cheap CI slices (module boundaries, Swift Testing migration, release-note
validation) that full `ci-gate.sh` also enforces.

## Gate composition

| Gate | Composition |
|---|---|
| `ci-gate.sh` | Generate/assert against HEAD, full-tree style, module boundaries, script syntax and regression tests, Swift Testing policy, release-note validation |
| `ci-gate.sh --fast` | Module boundaries, Swift Testing policy, and release-note validation only |
| `ci-assets-gate.sh` | Generate assets, assert, regenerate in a stable locale, assert again |
| `test-deploy.sh` | Release-time: `ci-gate.sh`, unit, then full UI, or the optional smoke canary |
| Main CI | Post-push on `main`: gate, one build-for-testing, parallel unit/full-smoke/exhaustive-UI jobs |

The shared build job produces test products for fan-out, including every
package test scheme so the unit job can run with `--no-build`. Smoke and
exhaustive UI rebuild app-only on artifact miss. `check-build-cache-paths.sh`
keeps local no-build freshness inputs aligned with the CI cache key.

## Output efficiency telemetry

Main CI profiles the existing verification boundaries automatically: the gate,
asset gate, shared build, package unit tests, smoke tests, and each exhaustive
UI shard. The wrapper streams stdout/stderr live and preserves the wrapped
command's status; profiling is metadata-only and advisory. Each record carries
the stable check label, CI/local environment, outcome, elapsed time, displayed
line/byte counts, and output policy. Command arguments and output contents are
not retained, and the measure is a stable line/byte proxy rather than a
tokenizer-specific estimate.

Normal verification is quiet. A report becomes actionable only for a sustained
or materially excessive signal (the profiler owns the thresholds), and CI
places at most three ranked advisories in the step summary. The profile
directory is uploaded separately from diagnostic artifacts with 30-day
retention; raw Xcode/test logs remain agent-visible only when a command prints
them, not merely because they exist in a diagnostic artifact.

Use these reports when investigating a local or hosted trend:

```sh
python3 Scripts/output-profile.py report --local
python3 Scripts/output-profile.py report --ci <artifact-dirs...>
python3 Scripts/output-profile.py report --actionable --top 3
```

`TRINKET_OUTPUT_PROFILE=0` is a debugging escape hatch. Set
`TRINKET_OUTPUT_PROFILE_DIR` when an isolated test needs a different metadata
directory; the CI default is `.DerivedData/OutputProfiles/`. The recurring
maintenance task consumes actionable evidence, edits only a clean checkout,
and leaves verified bounded changes uncommitted for review. Output profiling
does not fail a correctness gate.

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
