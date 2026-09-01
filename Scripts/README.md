# Scripts

This is the command index for Trinket's generated project, verification, asset,
and release tooling. The scripts and checked-in configuration are authoritative;
the linked guides explain routing and operating policy.

## Everyday workflow

```sh
./Scripts/generate.sh
./Scripts/test-package.sh BattleEngine
./Scripts/test.sh unit
./Scripts/agent-context.sh --agent --paths <changed-paths...>
./Scripts/handoff.sh --isolate --paths <changed-paths...>
./Scripts/new-plan.sh <PlanName>
```

Agents always use an isolated path-scoped handoff. Humans may omit `--isolate`
to reuse the shared warm build tree. Do not regenerate assets during ordinary
Swift iteration unless an asset manifest or source changed.

Run artifacts are ephemeral by default. Use the owning command's documented
keep/cleanup switches when an investigation needs to retain a successful run;
failed evidence remains available for triage.

Read these focused guides:

- [Documentation map](../Docs/README.md) — source-of-truth owners.
- [Verification and CI](../Docs/Platform/Verification.md) — task routing, test
  tiers, gate composition, style ownership, and diagnostics.
- [Simulator operations](../Docs/Platform/SimulatorOperations.md) — isolation,
  local Xcode setup, cache hygiene, and CrashReporter guidance.
- [Release process](../Docs/Platform/Release.md) — versions, commit messages,
  release notes, tags, and App Store handoff.
- [CI diagnostics](../Docs/AgentContext/ci-diagnostics.md) — structured failure
  reports and triage order. `./Scripts/agent-context.sh` discovers nested
  guides, context cards, and skills for the given paths.

## Command index

| Command | Purpose |
|---|---|
| `./Scripts/generate.sh` | Generate the Xcode project and authored derived content |
| `./Scripts/generate.sh --assets` | Also prepare art, music, SFX, and cinematics |
| `./Scripts/assert-generated-output.sh --idempotent` | Confirm regeneration produces no diff |
| `./Scripts/build.sh` | Build the app with the routed local toolchain |
| `./Scripts/build-for-testing.sh` | Rebuild app and package schemes for `test.sh … --no-build` runs against CI build artifacts |
| `./Scripts/build-for-testing.sh --app-only` | Rebuild only the app (CI shared build; smoke/UI artifact miss recovery) |
| `./Scripts/ci-path-filter.py` | CI path filter via the GitHub compare API (no full checkout); `code` / `assets` / `infra` outputs |
| `./Scripts/stage-ci-test-artifact.sh` | Stage Products + stamps for the CI `--no-build` fan-out artifact |
| `./Scripts/test-package.sh <Package>` | Run one package's tests |
| `./Scripts/test.sh unit` | Run all package unit suites |
| `./Scripts/test-timing.sh report` | Show per-suite wall-time history and hotspots from test runs |
| `./Scripts/test-timing.sh show --last 10` | Show recent run IDs, outcomes, targets, and result-bundle availability without hotspot output |
| `./Scripts/test.sh smoke` | Run the checked-in smoke registry |
| `./Scripts/test.sh smoke <Class...>` | Run targeted smoke classes |
| `./Scripts/test.sh ui <Target>` | Run one exhaustive UI target; bare full suite requires `TRINKET_ALLOW_FULL_UI=1` (CI-owned otherwise) |
| `./Scripts/performance.sh` | Ad hoc app + battle performance matrix (not CI) |
| `./Scripts/record-time-profiler.sh --output <path.trace>` | Host Time Profiler of the Trinket process (no `xctrace --device`; `--all-processes` is opt-in and slow) |
| `./Scripts/agent-context.sh --agent --paths …` | Print concise guidance and verification routing; use `--full` for full commands and `--working-tree --allow-broad-scope` only intentionally |
| `./Scripts/agent-watch-ci.sh [--sha …]` | Poll a hosted CI run for a commit; prints failed jobs and annotations when red |
| `./Scripts/agent-worktree.sh -h` | Create/list/remove isolated git worktrees for parallel agent sessions |
| `./Scripts/handoff.sh --isolate --paths …` | Canonical path-scoped source gate; use `--working-tree` only intentionally; always finishes with cheap CI slices (boundaries, Swift Testing, release notes) |
| `./Scripts/new-plan.sh <PlanName>` | Scaffold an expiring active execution plan under `Docs/Plans/`; completed plans move to `Docs/Plans/Archived/` |
| `./Scripts/ci-gate.sh` | Generation, style, boundaries, script regressions, and release-note validation |
| `./Scripts/ci-gate.sh --fast` | Cheap full-tree slices only (boundaries, Swift Testing, release notes); skips generation and style |
| `./Scripts/test-scripts.sh [--skip-docs]` | Script syntax/regressions; omit docs when a caller already ran `check-docs.py --final` |
| `./Scripts/ci-assets-gate.sh` | Asset generation, idempotence, and locale-stability gate |
| `python3 ./Scripts/check-docs.py [--final] [--keep-plan]` | Check links, structure, smoke classes, stale terms, and execution-plan lifecycle |
| `./Scripts/test-deploy.sh [--mode smoke]` | Pre-release deploy verification (`release.sh` calls this); `--mode smoke` is an optional canary |
| `./Scripts/agent-push-gate.sh` | Post-commit generation completeness; skips generate when classification has no content/project/asset inputs |
| `./Scripts/ci-diagnostics.sh [RESULTS_DIR]` | Aggregate the current diagnostics session |
| `./Scripts/ci-diagnostics.sh --stage-artifacts <RESULTS_DIR> <ARTIFACT_DIR>` | Stage structured artifacts, adding raw failure evidence only when needed |
| `./Scripts/ci-diagnostics.sh --cleanup [--keep] <RESULTS_DIR>` | Delete passed result/report history after staging; retain failures for current triage unless `--keep` |
| `./Scripts/change-budget.sh --paths …` | Advisory authored-surface report against HEAD; `--base <rev>` for CI ranges |
| `./Scripts/lint-analyze.sh` | CI-only advisory SwiftLint analyzer (`unused_import` / `unused_declaration`) after a compiler log exists; runs beside tests, never from handoff or style |
| `./Scripts/ensure-ci-tools.sh` | Install pinned XcodeGen, SwiftFormat, SwiftLint, ripgrep, and xcbeautify |
| `./Scripts/update-tools.sh [--apply]` | Report newer SwiftFormat/SwiftLint releases; with `--apply`, bump the pins in `tool-versions.env` (checksummed) and re-install |
| `./Scripts/run-simulator.sh` | Build and launch on a managed simulator |
| `./Scripts/prune-derived-data-cache.sh` | Prune safe, old local build artifacts |
| `./Scripts/balance-sweep.sh` | Run the headless battle balance sweep |
| `./Scripts/release.sh [--dry-run]` | Preview or execute a release |

Use `--help` where a command supports it; this index covers commands without a
dedicated help mode. Pinned tool versions live in
`Scripts/tool-versions.env`; package/build/generation roots and test plans live
in `Scripts/swift-source-dirs.env`; generated-output ownership lives in
`Scripts/config/generated-paths.tsv`; diagnostic budgets live in
`Scripts/config/diagnostic-limits.env`; simulator JSON queries live in
`Scripts/simctl_json.py`. The small helpers under `Scripts/lib/` own shared
mechanics only (tool PATH setup, app build arguments, media conversion/state
sorting, cache pruning, and infrastructure-failure matching); domain-specific
policy remains in the owning command.

## Toolchain ladder

Local and CI verification requires Xcode 26 or newer. If the simulator
toolchain is unavailable, run the non-simulator checks that the host supports
(`generate.sh`, generated-output assertion, boundaries, style, and `ci-gate.sh`)
and explicitly report skipped build/test work. Do not claim full verification
until the routed build and test commands pass with the required Xcode toolchain.
