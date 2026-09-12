# Command reference

For the everyday workflow, start at [Scripts](README.md). Open the section for the task; the tables are choices, not a checklist. Script usage and option parsing remain authoritative.

### Development

| Command | Purpose |
|---|---|
| `./Scripts/generate.sh` | Generate the Xcode project without cache reuse and authored derived content |
| `./Scripts/build.sh` | Compile only the app; `--release-device` verifies unsigned iOS Release compilation |
| `./Scripts/agent-context.sh --agent --paths …` | Print concise guidance and verification routing; add `--status` for global dirty counts and exact scoped status; use `--full` for path inventory, route metadata, and full commands and `--working-tree --allow-broad-scope` only intentionally |
| `python3 Scripts/agent-search.py <pattern> --scope <owner>` | Authored-first discovery: matching filenames/counts by default; plain identifiers promote exact filename stems outside docs; `--files` searches filenames; `--excerpts` for bounded lines, `--mode tests`, `docs`, or `generated` for other surfaces; omissions are explicit |
| `python3 Scripts/agent-read.py 'path.md#heading'` | Read a complete optional-reference section with source lines and parent headings; `--outline` lists anchors, and omitting the anchor reads the whole document |
| `node Scripts/agent-worktree.mjs create --task <slug>` | Optional worktree under `.worktrees/<slug>` on `agent/<slug>`; checkout policy lives in [AGENTS.md](../AGENTS.md#protect-the-workspace) |
| `node Scripts/agent-worktree.mjs legacy-detach create <slug>` | Legacy sibling `../Trinket-<slug>` checkout, detached at HEAD |
| `./Scripts/new-plan.sh <PlanName>` | Scaffold an active execution plan with an advisory review date under `Docs/Plans/`; completed outcomes go in `Docs/Plans/Archived/README.md` and the full plan is deleted |
| `./Scripts/ensure-ci-tools.sh` | Install pinned XcodeGen, SwiftFormat, SwiftLint, ripgrep, and xcbeautify |
| `./Scripts/update-tools.sh [--apply]` | Report newer SwiftFormat/SwiftLint releases; with `--apply`, bump the pins in `tool-versions.env` (checksummed) and re-install |
| `./Scripts/run-simulator.sh [--isolate] [--agent N]` | Build, resolve the app from the Trinket target’s Xcode build settings (60-second query limit), and launch on a managed simulator (default Trinket Run; `--isolate`/`--agent N` for the isolated pool) — also available as `run` alias via `node Scripts/setup-git-safety.mjs` |
| `./Scripts/promote.sh` | Build once under an isolated lease and install that app only on Trinket Run; build/install failures fail the command (also via `handoff.sh --mirror`) |
| `./Scripts/install-device.sh [--device …]` | Build, install, and launch Trinket on a connected physical iOS device; auto-selects the first paired device |

### Verification

| Command | Purpose |
|---|---|
| `./Scripts/assert-generated-output.sh --idempotent` | Confirm regeneration produces no diff |
| `./Scripts/build-for-testing.sh` | Rebuild app and package schemes for `test.sh … --no-build` runs against CI build artifacts |
| `./Scripts/build-for-testing.sh --app-only` | Build the app and UI test bundles, skipping package test schemes (CI shared build) |
| `./Scripts/test-package.sh <Package>` | Run one package's tests on iOS Simulator; `--destination` allows simulator name/UUID overrides, rejects other platforms, and cannot combine with generic `--build-for-testing` |
| `./Scripts/test.sh unit` | Run all package unit suites via the parallel `test-package.sh` owner |
| `./Scripts/test.sh smoke` | Run the checked-in smoke registry |
| `./Scripts/test.sh smoke <Class...>` | Run targeted smoke classes |
| `./Scripts/test.sh ui <Target>` | Run one exhaustive UI target; bare full suite requires `TRINKET_ALLOW_FULL_UI=1` (CI-owned otherwise) |
| `./Scripts/handoff.sh --isolate --paths …` | Canonical path-scoped source gate (headless by default); `--smoke` runs targeted UI smoke; `--mirror` mirrors to Trinket Run; `--dry-run` shows the full ordered plan including cheap CI slices |
| `./Scripts/ci-gate.sh` | Generation, style, boundaries, script regressions, Swift Testing policy, release-note validation, and artwork budget |
| `./Scripts/ci-gate.sh --fast` | Run only the ordered commands in [the cheap-slice registry](config/cheap-slices.txt); skips generation and style |
| `./Scripts/test-scripts.sh [--skip-docs] [--fast] [--paths <file> …]` | Script syntax/regressions; handoff passes its scope to select leaf families; unknown/shared scripts and unscoped CI run all suites. Runs docs unless already checked by the caller; `--fast` skips docs, media audio fixtures and shell regressions |
| `python3 ./Scripts/check-docs.py [--final] [--keep-plan] [--paths <file> …]` | Check links and structure globally; `--paths` scopes final active-plan closure only. Plan expiration is advisory; `check-plans.py` accepts the same flags |
| `./Scripts/check-api-bans.sh` | Banned legacy observation/navigation APIs plus XCTest-outside-UITests migration |

### Assets

| Command | Purpose |
|---|---|
| `./Scripts/report-art-memory.sh` | Estimate full-catalog decoded artwork size; interpretation and optional enforcement follow the [art pipeline](../ArtManifest/README.md#decoded-memory-report) |
| `./Scripts/generate.sh --assets` | Also prepare art, music, SFX, and cinematics |
| `./Scripts/ci-assets-gate.sh` | Asset generation, idempotence, and locale-stability gate |
| `./Scripts/prepare-audio-assets.sh [music\|sfx\|all]` | Validate music/SFX manifests, encode AAC, regenerate `MusicCatalog` / `SFXCatalog` |

### Release

| Command | Purpose |
|---|---|
| `./Scripts/test-deploy.sh [--mode smoke]` | Pre-release deploy verification (`release.sh` calls this); `--mode smoke` is an optional canary |
| `./Scripts/release.sh [--dry-run]` | Preview or execute a release |

### Diagnostics

| Command | Purpose |
|---|---|
| `python3 ./Scripts/test-timing.py report` | Show per-suite wall-time history and hotspots from test runs |
| `python3 ./Scripts/test-timing.py show --last 10` | Show recent run IDs, outcomes, targets, and result-bundle availability without hotspot output |
| `./Scripts/performance.sh` | Ad hoc app + battle performance matrix (not CI) |
| `./Scripts/record-time-profiler.sh --output <path.trace>` | Host Time Profiler of the Trinket process (no `xctrace --device`; `--all-processes` is opt-in and slow) |
| `./Scripts/agent-watch-ci.sh [--sha …]` | Poll a hosted CI run for a commit; prints failed jobs and annotations when red |
| `./Scripts/ci-diagnostics.sh [RESULTS_DIR]` | Aggregate the current diagnostics session |
| `./Scripts/ci-diagnostics.sh --cleanup [--keep] <RESULTS_DIR>` | Remove completed successful invocations individually after staging; retain failures and keep unfinished logs until orphan-retention expiry; `--keep` preserves evidence |
| `./Scripts/change-budget.sh --paths …` | Advisory authored-surface report against HEAD; `--base <rev>` for CI ranges |
| `./Scripts/prune-derived-data-cache.sh` | Prune safe, old local build artifacts |
| `./Scripts/balance-sweep.sh` | Run the headless battle balance sweep |

### Internal helpers

These helpers are sourced or invoked by commands, Git hooks, or CI workflows. Listed here so the index stays honest
(`check-docs.py` enforces this list against `Scripts/*.sh`).

| Command | Owner / entry point |
|---|---|
| `./Scripts/check-staged-project.sh` | Pre-commit check of the staged project against staged inputs; preserves the index and working files |
| `./Scripts/ci-path-filter.py` | CI path filter via the GitHub compare API (no full checkout); `code` / `assets` / `infra` outputs |
| `./Scripts/stage-ci-test-artifact.sh` | Archive Products + build stamps in a tar file for CI `--no-build` test jobs |
| `./Scripts/agent-push-gate.sh` | Internal pre-push generation completeness; invoked automatically by pre-push, not a manual post-commit step |
| `./Scripts/ci-diagnostics.sh --stage-artifacts <RESULTS_DIR> <ARTIFACT_DIR>` | Stage structured artifacts outside the source results tree and its ancestors, adding raw failure evidence only when needed |
| `./Scripts/lint-analyze.sh [SwiftPath ...]` | On-demand clean app build and analysis; optional file/directory scope, fails on unused imports or zero analyzed files; never CI, handoff, or style |
| `./Scripts/run-env.sh`, `./Scripts/xcode-runner.sh`, `./Scripts/build-freshness.sh` | Run environment, Xcode execution, generated-input freshness, and `--no-build` stamps for `build` / `test` / `generate` / `run-simulator` |
| `./Scripts/change-classification.sh` | Sourced by `handoff` / `agent-context` / `agent-push-gate` |
| `./Scripts/ensure-simulator.sh` | Invoked by `test` / `run-simulator` slot setup |
| `./Scripts/check-module-boundaries.sh`, `./Scripts/check-comment-ban.sh`, `./Scripts/check-agent-invariants.sh`, `./Scripts/check-exclusivity-footguns.sh` | Invoked via style gate / `ci-gate --fast` cheap slices |
| `./Scripts/check-artwork-budget.sh`, `./Scripts/release-notes.sh` | Invoked via `ci-gate` cheap slices |
| `./Scripts/check-build-cache-paths.sh`, `./Scripts/check-testplan-sync.py`, `./Scripts/check-links.py`, `./Scripts/check-plans.py` | Invoked via `test-scripts.sh` / `check-docs.py` |
| `./Scripts/check-unused-assets.py`, `./Scripts/check-accessibility-ids.py`, `./Scripts/check-ui-style.py` | Invoked via style / asset gates |
| `./Scripts/prepare-assets.sh`, `./Scripts/prepare-art-assets.sh`, `./Scripts/prepare-cinematic-assets.sh`, `./Scripts/prepare-app-icon.sh` | Invoked via `generate.sh --assets` |
| `./Scripts/content_codegen.py` (helpers in `internal/content/`) | Invoked via `generate.sh` |
| `./Scripts/lint.sh`, `./Scripts/format.sh` | Invoked via style gate |
| `./Scripts/validate-commit-msg.sh` | Invoked via commit-msg hook |
| `./Scripts/ci-infra-rerun.sh` | Invoked via `agent-watch-ci.sh` |
| `./Scripts/ensure-git-cliff.sh` | Invoked by release tooling |
| `./Scripts/collect-performance-results.py` | Invoked by `performance.sh` |
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
policy remains in the owning command. `Scripts/script_test_selection.py` owns
leaf-script regression families; shared inputs and unknown scripts fall back to
the full suite. It is consumed by `test-scripts.sh`, not a separate gate.

## Toolchain ladder

Local and CI verification requires Xcode 26 or newer. If the simulator
toolchain is unavailable, run the non-simulator checks that the host supports
(`generate.sh`, generated-output assertion, boundaries, style, and `ci-gate.sh`)
and explicitly report skipped build/test work. Do not claim full verification
until the routed build and test commands pass with the required Xcode toolchain.
