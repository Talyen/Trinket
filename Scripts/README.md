# Scripts

This is the command index for Trinket's generated project, verification, asset,
and release tooling. The scripts and checked-in configuration are authoritative;
the linked guides explain routing and operating policy.

## Everyday workflow

```sh
./Scripts/agent-context.sh --agent --paths <changed-paths...>
./Scripts/handoff.sh --isolate --paths <changed-paths...>
```

These are the routing and final verification steps. Between them, use the
focused checks appropriate to the task; the command index below lists choices,
not a checklist. Create an execution plan only when durable coordination or
resumption is useful; see [Plans](../Docs/Plans/README.md).

Ordinary Swift work starts with focused iteration, not manual generation:
generation runs automatically when classified inputs require it (build
freshness and handoff plan it). Run `./Scripts/generate.sh` directly only
when changing generation inputs (content, `project.yml`, assets).

Agents always use an isolated path-scoped handoff. Humans may omit `--isolate`
to reuse the shared warm build tree. Do not regenerate assets during ordinary
Swift iteration unless an asset manifest or source changed. The user-facing
flow is focused iteration → path-scoped handoff, followed by commit and push
only when requested. Pre-push runs its own generation/style/package safeguards
automatically.

Run artifacts are ephemeral by default. Use the owning command's documented
keep/cleanup switches when an investigation needs to retain a successful run;
failed evidence remains available for triage. Script regressions retain failed
logs under `$RESULTS_DIR/script-tests.*` or `.DerivedData/ScriptTestResults/`;
failures print the suite, exit status, bounded excerpt, and full log path.
Successful script logs are removed. `handoff.sh` prints its final outcome after
all selected checks and cheap slices finish; a failure identifies the stopped check.

Build/test wrapper help and option parsing do not reserve build/simulator slots;
style-only checks also run without a slot. Package test/build commands require registered,
unique package names and prepare generated inputs before compiling.
`handoff.sh --dry-run --final` previews the final documentation gate without
executing it.

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
| `./Scripts/build.sh` | Alias for `build-for-testing.sh --app-only` (kept for the short name) |
| `./Scripts/build-for-testing.sh` | Rebuild app and package schemes for `test.sh … --no-build` runs against CI build artifacts |
| `./Scripts/build-for-testing.sh --app-only` | Rebuild only the app (CI shared build; smoke/UI artifact miss recovery) |
| `./Scripts/ci-path-filter.py` | CI path filter via the GitHub compare API (no full checkout); `code` / `assets` / `infra` outputs |
| `./Scripts/stage-ci-test-artifact.sh` | Stage Products + stamps for the CI `--no-build` fan-out artifact |
| `./Scripts/test-package.sh <Package>` | Run one package's tests on iOS Simulator; `--destination` allows simulator name/UUID overrides, rejects other platforms, and cannot combine with generic `--build-for-testing` |
| `./Scripts/test.sh unit` | Run all package unit suites via the parallel `test-package.sh` owner |
| `python3 ./Scripts/test-timing.py report` | Show per-suite wall-time history and hotspots from test runs |
| `python3 ./Scripts/test-timing.py show --last 10` | Show recent run IDs, outcomes, targets, and result-bundle availability without hotspot output |
| `./Scripts/test.sh smoke` | Run the checked-in smoke registry |
| `./Scripts/test.sh smoke <Class...>` | Run targeted smoke classes |
| `./Scripts/test.sh ui <Target>` | Run one exhaustive UI target; bare full suite requires `TRINKET_ALLOW_FULL_UI=1` (CI-owned otherwise) |
| `./Scripts/performance.sh` | Ad hoc app + battle performance matrix (not CI) |
| `./Scripts/record-time-profiler.sh --output <path.trace>` | Host Time Profiler of the Trinket process (no `xctrace --device`; `--all-processes` is opt-in and slow) |
| `./Scripts/agent-context.sh --agent --paths …` | Print concise guidance and verification routing; use `--full` for path inventory, route metadata, and full commands and `--working-tree --allow-broad-scope` only intentionally |
| `./Scripts/agent-watch-ci.sh [--sha …]` | Poll a hosted CI run for a commit; prints failed jobs and annotations when red |
| `node Scripts/agent-worktree.mjs create --task <slug>` | Optional worktree under `.worktrees/<slug>` on `agent/<slug>`; checkout policy lives in [AGENTS.md](../AGENTS.md#protect-the-workspace) |
| `node Scripts/agent-worktree.mjs legacy-detach create <slug>` | Legacy sibling `../Trinket-<slug>` checkout, detached at HEAD |
| `./Scripts/handoff.sh --isolate --paths …` | Canonical path-scoped source gate (headless by default); `--smoke` runs targeted UI smoke; `--mirror` mirrors to Trinket Run; `--dry-run` shows the full ordered plan including cheap CI slices |
| `./Scripts/new-plan.sh <PlanName>` | Scaffold an expiring active execution plan under `Docs/Plans/`; completed outcomes go in `Docs/Plans/Archived/README.md` and the full plan is deleted |
| `./Scripts/ci-gate.sh` | Generation, style, boundaries, script regressions, Swift Testing policy, release-note validation, and artwork budget |
| `./Scripts/ci-gate.sh --fast` | Cheap full-tree slices only (boundaries, API bans, release notes, artwork budget) from `Scripts/config/cheap-slices.txt`; skips generation and style |
| `./Scripts/test-scripts.sh [--skip-docs] [--fast]` | Script syntax/regressions; runs docs by default, omit docs when a caller already ran `check-docs.py` (mixed script/docs scope or `--final`); `--fast` skips docs, media audio fixtures, and shell regressions for a quick loop |
| `./Scripts/ci-assets-gate.sh` | Asset generation, idempotence, and locale-stability gate |
| `python3 ./Scripts/check-docs.py [--final] [--keep-plan]` | Check links, structure, smoke classes, stale terms, and execution-plan lifecycle |
| `./Scripts/test-deploy.sh [--mode smoke]` | Pre-release deploy verification (`release.sh` calls this); `--mode smoke` is an optional canary |
| `./Scripts/agent-push-gate.sh` | Internal pre-push generation completeness; invoked automatically by pre-push, not a manual post-commit step |
| `./Scripts/ci-diagnostics.sh [RESULTS_DIR]` | Aggregate the current diagnostics session |
| `./Scripts/ci-diagnostics.sh --stage-artifacts <RESULTS_DIR> <ARTIFACT_DIR>` | Stage structured artifacts, adding raw failure evidence only when needed |
| `./Scripts/ci-diagnostics.sh --cleanup [--keep] <RESULTS_DIR>` | Delete passed result/report history after staging; retain failures for current triage unless `--keep` |
| `./Scripts/change-budget.sh --paths …` | Advisory authored-surface report against HEAD; `--base <rev>` for CI ranges |
| `./Scripts/lint-analyze.sh` | CI blocking SwiftLint analyzer on dead imports (`unused_import` fails; `capture_variable` / `unused_declaration` advisory) after a compiler log exists; runs beside tests, never from handoff or style |
| `./Scripts/ensure-ci-tools.sh` | Install pinned XcodeGen, SwiftFormat, SwiftLint, ripgrep, and xcbeautify |
| `./Scripts/update-tools.sh [--apply]` | Report newer SwiftFormat/SwiftLint releases; with `--apply`, bump the pins in `tool-versions.env` (checksummed) and re-install |
| `./Scripts/run-simulator.sh [--isolate] [--agent N]` | Build, resolve the app from the Trinket target’s Xcode build settings (60-second query limit), and launch on a managed simulator (default Trinket Run; `--isolate`/`--agent N` for the isolated pool) — also available as `run` alias via `node Scripts/setup-git-safety.mjs` |
| `./Scripts/prune-derived-data-cache.sh` | Prune safe, old local build artifacts |
| `./Scripts/prepare-audio-assets.sh [music\|sfx\|all]` | Validate music/SFX manifests, encode AAC, regenerate `MusicCatalog` / `SFXCatalog` |
| `./Scripts/check-api-bans.sh` | Banned legacy observation/navigation APIs plus XCTest-outside-UITests migration |
| `./Scripts/promote.sh` | Install an isolated agent build into the human simulator without relaunch (also via `handoff.sh --mirror`) |
| `./Scripts/build-freshness.sh` | Generated-input freshness and `--no-build` stamp helpers sourced by build/test commands |
| `./Scripts/balance-sweep.sh` | Run the headless battle balance sweep |
| `./Scripts/release.sh [--dry-run]` | Preview or execute a release |

### Advanced / internal (owned by another command, not everyday entry points)

These scripts are intentionally not everyday commands; they are sourced or
invoked by the indexed commands above. Listed here so the index stays honest
(`check-docs.py` enforces this list against `Scripts/*.sh`).

| Command | Owner / entry point |
|---|---|
| `./Scripts/run-env.sh`, `./Scripts/xcode-runner.sh`, `./Scripts/build-freshness.sh` | Sourced by `build` / `test` / `generate` / `run-simulator` |
| `./Scripts/change-classification.sh` | Sourced by `handoff` / `agent-context` / `agent-push-gate` |
| `./Scripts/ensure-simulator.sh` | Invoked by `test` / `run-simulator` slot setup |
| `./Scripts/check-module-boundaries.sh`, `./Scripts/check-comment-ban.sh`, `./Scripts/check-agent-invariants.sh`, `./Scripts/check-exclusivity-footguns.sh` | Invoked via style gate / `ci-gate --fast` cheap slices |
| `./Scripts/check-artwork-budget.sh`, `./Scripts/release-notes.sh` | Invoked via `ci-gate` cheap slices |
| `./Scripts/check-build-cache-paths.sh`, `./Scripts/check-testplan-sync.py`, `./Scripts/check-links.py`, `./Scripts/check-plans.py` | Invoked via `test-scripts.sh` / `check-docs.py` |
| `./Scripts/check-unused-assets.py`, `./Scripts/check-accessibility-ids.py`, `./Scripts/check-ui-style.py` | Invoked via style / asset gates |
| `./Scripts/prepare-assets.sh`, `./Scripts/prepare-art-assets.sh`, `./Scripts/prepare-cinematic-assets.sh`, `./Scripts/prepare-app-icon.sh` | Invoked via `generate.sh --assets` |
| `./Scripts/content_codegen.py` (+ `content_codegen_modifiers.py`, `content_codegen_triggers.py`) | Invoked via `generate.sh` |
| `./Scripts/lint.sh`, `./Scripts/format.sh` | Invoked via style gate |
| `./Scripts/validate-commit-msg.sh` | Invoked via commit-msg hook |
| `./Scripts/ci-infra-rerun.sh` | Invoked via `agent-watch-ci.sh` |
| `./Scripts/ensure-git-cliff.sh`, `./Scripts/report-art-memory.sh`, `./Scripts/record-time-profiler.sh`, `./Scripts/collect-performance-results.py` | Ad hoc / release diagnostics |
| `./Scripts/lib/args.sh`, `./Scripts/lib/lock.sh`, `./Scripts/lib/simctl.sh`, `./Scripts/lib/slots.sh` | Shared helpers (no direct CLI) |

Use `--help` where a command supports it; this index covers commands without a
dedicated help mode. Pinned tool versions live in
`Scripts/tool-versions.env`; format roots live in `Scripts/format-dirs.env` and
package/build/generation roots plus test plans in `Scripts/build-inputs.env`
(both sourced by the `Scripts/swift-source-dirs.env` shim); generated-output ownership lives in
`Scripts/config/generated-paths.tsv`; diagnostic budgets live in
`Scripts/config/diagnostic-limits.env`; simulator JSON queries live in
`Scripts/simctl_json.py`; cheap CI slices live in `Scripts/config/cheap-slices.txt`. The small helpers under `Scripts/lib/` own shared
mechanics only (tool PATH setup, app build arguments, media conversion/state
sorting, cache pruning, and infrastructure-failure matching); domain-specific
policy remains in the owning command.

## Toolchain ladder

Local and CI verification requires Xcode 26 or newer. If the simulator
toolchain is unavailable, run the non-simulator checks that the host supports
(`generate.sh`, generated-output assertion, boundaries, style, and `ci-gate.sh`)
and explicitly report skipped build/test work. Do not claim full verification
until the routed build and test commands pass with the required Xcode toolchain.
