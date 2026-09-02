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
| Fast gate | `ci-gate.sh --fast` | Cheap full-tree slices only (boundaries, Swift Testing, release notes, artwork budget) — canonical registry `Scripts/config/cheap-slices.txt` |
| Local canary | `test-deploy.sh --mode smoke` | Optional human confidence: gate, unit, and smoke |
| Release confidence | `release.sh` / `test-deploy.sh` | Pre-release only: gate, unit, and full UI (the one sanctioned local full-UI run) |
| Main CI | Shared `tests.yml` workflow | Post-push on `main` (no pull-request workflow): path filter, then generate/style, app-only build, sharded unit (Engine/State/Features) for faster push feedback, and sharded smoke; exhaustive is advisory nightly/dispatch |
| Nightly exhaustive | `ci.yml` schedule + `workflow_dispatch` exhaustive | Full sharded exhaustive UI off the push path; visible but never blocks `CI OK` |
| Local debugging / performance | `test.sh ui <Target>` / `performance.sh` | Single UI target or ad hoc performance; the full exhaustive suite is CI-owned |

Run `./Scripts/agent-context.sh --agent --paths <files...>` after touched paths
are known. Use `--working-tree` only for an intentional whole-tree scope. The
briefing prints the required/optional read contract and applicable handoff
route; rerun it when requested work or an encountered fix crosses into another
owner. The final path list is the union of requested work and every explicitly
adopted fix, not the task's initial path list.

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
reruns in the same slot. Routine handoff is headless by default. Exact flags
(`--smoke`, `--mirror`, `--dry-run`, `--final`) live in
[`Scripts/README.md`](../../Scripts/README.md) and each script's usage text.

`handoff.sh` is the canonical path-scoped route. It composes generation,
style, package, compile, documentation, and idempotence checks from the
changed paths, including paths added by encountered fixes. Docs and Markdown edits route `check-docs.py`.

## Gate composition

| Gate | Composition |
|---|---|
| `ci-gate.sh` | Generate/assert against HEAD, full-tree style, module boundaries, script syntax and regression tests, Swift Testing policy, release-note validation, artwork budget |
| `ci-gate.sh --fast` | Module boundaries, Swift Testing policy, release-note validation, and artwork budget only — from `Scripts/config/cheap-slices.txt` |
| `ci-assets-gate.sh` | Generate assets, assert, regenerate in a stable locale, assert again |
| `test-deploy.sh` | Release-time: `ci-gate.sh`, unit, then full UI, or the optional smoke canary |
| Main CI | Post-push on `main`: path filter, generation/style, app build, package unit, and smoke for product changes; advisory analysis and exhaustive UI do not block `CI OK` |
| Nightly exhaustive | Scheduled or manually dispatched exhaustive UI; advisory and reported separately from `CI OK` |

The shared build job produces app test products for smoke and exhaustive UI
fan-out, while package unit tests compile their own schemes in parallel. Exact
shards, artifact contracts, cache inputs, and advisory job behavior belong to
the checked-in workflows ([tests.yml](../../.github/workflows/tests.yml) and
related workflow files); update this guide only when the verification policy
changes.

## Style and boundary ownership

| Check | Owns |
|---|---|
| SwiftFormat | Mechanical Swift formatting and preferred rewrites |
| SwiftLint | API idioms, semantics, size, and unsafe operations |
| `check-ui-style.sh` | Product colors, materials, and chrome routed through `TrinketDesign` |
| `check-platform-api-bans.sh` | Repository-banned legacy observation/navigation APIs, mirrored from SwiftLint for portable builds |
| `check-exclusivity-footguns.sh` | Suspicious `inout` access to stored properties |
| `check-agent-invariants.sh` | BattleEngine entropy, test `Task.sleep`, persistence `try?`, undocumented concurrency escapes, SwiftLint disables without reasons |
| `check-accessibility-ids.sh` | Unique `AccessibilityID` constants; UITests must query `AccessibilityID.*` |
| `check-comment-ban.sh` | Banned `//` in Swift authored sources (allowlist: `swift-tools-version` / `swiftlint:disable` / `swiftformat:disable` / `Generated` headers; transitional `*Check: allow` / `Concurrency-Safety:`) |
| `check-module-boundaries.sh` | Package layering and imports |

`Color.primary`, `.secondary`, and `.clear` remain valid adaptive primitives.
Feature-specific product colors and visual effects go through the design system.
Use a checker-approved `UIStyleCheck: allow - reason` annotation only for a
narrow content/art exception that the semantic API cannot express; never use it
to bypass product chrome routing.

## Failures and reporting

Read structured invocation reports before raw build logs. Use
`./Scripts/ci-diagnostics.sh <results-dir>` to aggregate them and follow
[CI diagnostics](../AgentContext/ci-diagnostics.md) for classification and
escalation. Never kill foreign Xcode or Simulator processes.

The push gate may print an advisory change-budget report. Warnings do not fail
the task, but unusual production/test surface growth needs a necessity statement
and the simpler alternative that was rejected. Timing logs are diagnostic data,
not a routine optimization mandate.

Before a requested push, run `agent-push-gate.sh` after committing. Commit
format, hooks, and push preconditions live in [Release.md](Release.md);
receipt reuse and idempotent-assert behavior are documented in that guide and
in [`Scripts/README.md`](../../Scripts/README.md).

Land on `main` by direct push; do not open pull requests. After a red CI run,
triage with `./Scripts/ci-diagnostics.sh` and
[ci-diagnostics.md](../AgentContext/ci-diagnostics.md); do not invent a separate
fixer playbook. Do not require `tests / CI OK` as a GitHub push gate on `main`.
