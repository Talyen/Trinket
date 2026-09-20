# Command reference

For the everyday workflow, start at [Scripts](README.md). Open the section for the task; the tables are choices, not a checklist. Script usage and option parsing remain authoritative.

### Development

| Command | Purpose |
|---|---|
| `./Scripts/generate.sh [--assets [--kind art\|cinematic\|music\|sfx\|app-icon\|all]] [--skip-xcodegen]` | Generate the Xcode project without cache reuse and authored derived content (`--assets` also prepares art/music/SFX/cinematics; `--kind` prepares one asset kind; `--skip-xcodegen` runs content/asset codegen only) |
| `./Scripts/build.sh` | Compile only the app; `--release-device` verifies unsigned iOS Release compilation |
| `./Scripts/agent-context.sh --agent --paths …` | Print concise guidance and verification routing; add `--status` for global dirty counts and exact scoped status; add `--smoke` to preview the smoke route; use `--full` for path inventory, route metadata, and full commands and `--working-tree --allow-broad-scope` only intentionally |
| `python3 Scripts/agent-search.py <pattern> --scope <owner>` | Authored-first discovery: matching filenames/counts by default; plain identifiers rank exact stems, filename words/prefixes, then declarations before references outside docs; `--offset`/`--expect` continuations avoid repeats and reject changed results; `--overview` pages owner counts/entry points; `--files` searches filenames (`--mode assets --files` includes binary media names); `--excerpts` for bounded lines, `--mode tests`, `docs`, or `generated` for other surfaces; omissions are explicit |
| `python3 Scripts/agent-diff.py --paths <files...> [--staged] [--generated] [--stat]` | Authored patches and generated statistics; complete-hunk pages default to 12,000 characters (`--max-chars`); follow fingerprinted continuation commands or explicitly use `--full`; default is unstaged, untracked files are listed for explicit reads; `--generated` expands generated patches; whole-tree review requires `--working-tree` |
| `python3 Scripts/agent-read.py 'path.md#heading'` | Read a complete optional-reference section with source lines and parent headings; `--outline` lists anchors, and unanchored documents over 12,000 characters return navigation only (`--full` reads the complete document); Swift/Python `--outline` lists qualified types/members with source ranges (`--include-locals` adds locals); `--symbol Name` reads one complete lexical declaration or lists ambiguous candidates; `--lines START:END` reads a selected range |
| `python3 Scripts/content-inspect.py --id <id>` | Exact authored ContentManifest/ability-ID lookup with labeled fields and source locations; `--trigger <canonicalField>` finds DSL usage through the shared parser; `--kind`, `--offset`, `--limit`, `--full`, and optional `--references` control retrieval; `--kind abilities` points to authored tier declarations |
| `node Scripts/agent-worktree.mjs create --task <slug>` | Optional worktree under `.worktrees/<slug>` on `agent/<slug>`; checkout policy lives in [AGENTS.md](../AGENTS.md#protect-the-workspace) |
| `node Scripts/agent-worktree.mjs legacy-detach create <slug>` | Legacy sibling `../Trinket-<slug>` checkout, detached at HEAD |
| `./Scripts/new-plan.sh <PlanName>` | Scaffold an active execution plan with an advisory review date under `Docs/Plans/`; completed outcomes go in `Docs/Plans/Archived/README.md` and the full plan is deleted |
| `./Scripts/ensure-ci-tools.sh` | Install pinned XcodeGen, SwiftFormat, SwiftLint, ripgrep, and xcbeautify |
| `./Scripts/update-tools.sh [--apply]` | Report newer SwiftFormat/SwiftLint releases; with `--apply`, bump the pins in `tool-versions.env` (checksummed) and re-install |
| `./Scripts/run-simulator.sh [--isolate] [--agent N] [--inspect]` | Build, resolve the app from the Trinket target’s Xcode build settings (60-second query limit), and launch on a managed simulator (default Trinket Run; `--isolate`/`--agent N` for the isolated pool); `--inspect` holds the lease in a terminal until `stop` or input closes (see [inspection workflow](../Docs/Platform/SimulatorOperations.md#inspection-lease-and-capture)) — also available as `run` alias via `node Scripts/setup-git-safety.mjs` |
| `./Scripts/promote.sh [--quiet]` | Build once under an isolated lease and install that app only on Trinket Run; build/install failures fail the command (also via `handoff.sh --mirror`) |
| `./Scripts/install-device.sh [--device …]` | Build, install, and launch Trinket on a connected physical iOS device; auto-selects the first paired device |

### Verification

| Command | Purpose |
|---|---|
| `./Scripts/assert-generated-output.sh [--regenerate] [--assets] [--strict-assets] --idempotent` | Confirm regeneration produces no diff (`--regenerate` runs `generate.sh` first; `--assets` includes art/music/SFX/cinematic outputs; `--strict-assets` fingerprints full media trees) |
| `./Scripts/build-for-testing.sh` | Rebuild app and package schemes for `test.sh … --no-build` runs against CI build artifacts |
| `./Scripts/build-for-testing.sh --app-only` | Build the app and UI test bundles, skipping package test schemes (CI shared build) |
| `./Scripts/test-package.sh [--no-build] [--build-for-testing] [--destination …] [--iterations …] [--run-tests-until-failure] [--include-balance-sweep-tests] [--quiet] [--verbose] <Package> [Package...]` | Run one or more packages' tests on iOS Simulator; `--destination` allows simulator name/UUID overrides, rejects other platforms, and cannot combine with generic `--build-for-testing`; `--iterations` and `--run-tests-until-failure` support bounded diagnostic repetition; multiple packages emit an aggregate failure summary with retained report paths, `--verbose` expands worker output |
| `./Scripts/test.sh unit [--no-build] [--app-only] [--quiet] [--verbose]` | Run all package unit suites via the parallel `test-package.sh` owner (`--app-only` is a compile-only app build) |
| `./Scripts/test.sh style [--no-build]` | Run the style gate (format/lint/UI style/API bans/exclusivity/invariants/accessibility IDs) |
| `./Scripts/test.sh performance [--scenario …] [--group …]` | List/run the performance matrix via `performance.sh` selection |
| `./Scripts/test.sh smoke [--no-build]` | Run the checked-in smoke registry |
| `./Scripts/test.sh smoke <Class...>` | Run targeted smoke classes |
| `./Scripts/test.sh ui <Target>` | Run one exhaustive UI target; bare full suite requires `TRINKET_ALLOW_FULL_UI=1` (CI-owned otherwise) |
| `./Scripts/handoff.sh --isolate --paths …` | Canonical path-scoped source gate (headless by default); composition in [Verification.md](../Docs/Platform/Verification.md#gate-composition); `--smoke` runs targeted UI smoke, `--mirror` installs on Trinket Run, `--dry-run` previews the plan, `--final` runs plan closure, `--keep-plan` permits an unfinished plan with `--final`, `--working-tree` opts into whole-tree classification; `--quiet` retains child logs and prints one outcome per phase plus bounded failures |
| `./Scripts/ci-gate.sh` | Full gate; composition in [Verification.md](../Docs/Platform/Verification.md#gate-composition) |
| `./Scripts/ci-gate.sh --fast` | Run only the ordered commands in [the cheap-slice registry](config/cheap-slices.txt); skips generation and style |
| `./Scripts/test-scripts.sh [--skip-docs] [--fast] [--paths <file> …]` | Script syntax/regressions with leaf-family selection (`script_test_selection.py`); runs docs unless the caller already checked them |
| `python3 ./Scripts/check-docs.py [--final] [--keep-plan] [--paths <file> …]` | Check links and structure globally; `--paths` scopes final active-plan closure only. Plan expiration is advisory; `check-plans.py` accepts the same flags |
| `./Scripts/check-api-bans.sh` | Banned legacy observation/navigation APIs plus XCTest-outside-UITests migration |

### Headless playthroughs

Manual only; [scope, evidence, and interpretation](../Docs/Platform/HeadlessPlaythroughs.md).

```sh
./Scripts/playthrough-sweep.sh --scenarios 4 --seed 42 --horizon 2
./Scripts/playthrough-sweep.sh --mode contracts --full-access --horizon 10 --policy setupAware-v1
./Scripts/playthrough-sweep.sh --scenario PlaythroughReports/example/career-0000/scenario.json
./Scripts/playthrough-sweep.sh --replay-bundle PlaythroughReports/example/career-0000
./Scripts/playthrough-sweep.sh --crash-proof
./Scripts/playthrough-sweep.sh --baseline PlaythroughReports/baseline/report.json --scenarios 4 --seed 42 --horizon 2
```

`--output` must name a new directory (default `PlaythroughReports/<timestamp>`).
`--hero`/`--companion` choose starter IDs; `--full-access` simulates content ownership.
`--timeout` bounds each worker in seconds. `--help` lists modes and policies without
acquiring a Simulator. The wrapper acquires isolation, builds the AppState test
product, and supplies explicit worker requests; no nightly automation is created.
Read `report-agent.json` for compact derived findings and recommendations; use
`report.html` for human review and reserve `report.json` plus worker evidence for
targeted diagnostics.

### Assets

| Command | Purpose |
|---|---|
| `./Scripts/report-art-memory.sh [--enforce]` | Estimate full-catalog decoded artwork size; `--enforce` fails over budget; interpretation and optional enforcement follow the [art pipeline](../ArtManifest/README.md#decoded-memory-report) |
| `./Scripts/generate.sh --assets` | Also prepare art, music, SFX, and cinematics (add `--kind <kind>` for one pipeline, `--skip-xcodegen` for codegen only) |
| `./Scripts/ci-assets-gate.sh` | Asset generation, idempotence, and locale-stability gate |
| `./Scripts/prepare-audio-assets.sh [music\|sfx\|all]` | Validate music/SFX manifests, encode AAC, regenerate `MusicCatalog` / `SFXCatalog` |

### Release

| Command | Purpose |
|---|---|
| `./Scripts/setup-testflight.sh` | Install local Ruby/Bundler/Fastlane tooling with locked gems; [configuration](../Docs/Platform/Release.md#one-time-testflight-setup) stays outside Git |
| `./Scripts/testflight.sh [--doctor \| --dry-run \| --resume RUN] [--config FILE] [--notes FILE] [--cloud-sync YES\|NO] [--timeout SECONDS]` | Verify a clean checkout, archive/sign, upload, and confirm internal TestFlight availability; retain evidence for recovery; no Git mutations or review submission |
| `./Scripts/test-deploy.sh [--mode smoke\|ui] [--no-build]` | Pre-release deploy verification (`release.sh` calls this); `--mode smoke` is an optional canary |
| `./Scripts/release.sh [--version X.Y.Z] [--since-tag TAG] [--skip-tests] [--dry-run] [--no-tag]` | Preview or execute a release (`--version` pins semver, `--since-tag` sets the notes range, `--skip-tests` skips deploy verification, `--no-tag` commits without tagging) |

### Diagnostics

| Command | Purpose |
|---|---|
| `python3 ./Scripts/test-timing.py report` | Show per-suite wall-time history and hotspots from test runs |
| `python3 ./Scripts/test-timing.py show --last 10` | Show recent run IDs, outcomes, targets, and result-bundle availability without hotspot output |
| `python3 ./Scripts/test-timing.py record --mode … --run …` | Record one timing entry from a result bundle |
| `python3 ./Scripts/test-timing.py assert-budget` | Fail when recorded timings exceed the configured budget |
| `./Scripts/performance.sh [--scenario ID] [--group GROUP] [--list]` | Ad hoc app + battle performance matrix (not CI); `--list` prints scenarios/groups, default is one pass |
| `./Scripts/record-time-profiler.sh --output <path.trace> [--time-limit 8s] [--attach Trinket] [--all-processes] [--print-command]` | Host Time Profiler of the Trinket process (no `xctrace --device`; `--all-processes` is opt-in and slow; `--print-command` prints without recording) |
| `./Scripts/agent-watch-ci.sh [--ref <branch>] [--sha …] [--scope standard\|exhaustive] [--poll-seconds <n>] [--verbose]` | Poll a hosted CI run for a commit; prints failed jobs and annotations when red |
| `./Scripts/ci-diagnostics.sh [RESULTS_DIR]` | Aggregate the current diagnostics session (`--reset` clears it) |
| `./Scripts/ci-diagnostics.sh --cleanup [--keep] <RESULTS_DIR>` | Remove completed successful invocations individually after staging; retain failures and keep unfinished logs until orphan-retention expiry; `--keep` preserves evidence |
| `./Scripts/change-budget.sh --paths …` | Advisory authored-surface signals against HEAD; counts can include pre-existing work and are not justification quotas; `--base <rev>` for CI ranges |
| `./Scripts/prune-derived-data-cache.sh` | Prune safe, old local build artifacts |
| `./Scripts/balance-sweep.sh` | Run the headless battle balance sweep |

### Internal helpers

These helpers are sourced or invoked by commands, Git hooks, or CI workflows. Listed here so the index stays honest
(`check-docs.py` enforces this list against `Scripts/*.sh`).

| Command | Owner / entry point |
|---|---|
| `python3 Scripts/package-diagnostics.py [--verbose] <worker-output-dir> <packages...>` | Aggregate the current package run’s outcomes and deduplicated diagnostics; invoked by `test-package.sh` |
| `./Scripts/check-staged-project.sh` | Pre-commit check of the staged project against staged inputs; preserves the index and working files |
| `./Scripts/ci-path-filter.py` | CI path filter via the GitHub compare API (no full checkout); `code` / `assets` / `infra` outputs |
| `./Scripts/stage-ci-test-artifact.sh` | Archive Products + build stamps in a tar file for CI `--no-build` test jobs |
| `./Scripts/agent-push-gate.sh` | Internal pre-push generation completeness; invoked automatically by pre-push, not a manual post-commit step |
| `./Scripts/ci-diagnostics.sh --stage-artifacts <RESULTS_DIR> <ARTIFACT_DIR>` | Stage structured artifacts outside the source results tree and its ancestors, adding raw failure evidence only when needed |
| `./Scripts/lint-analyze.sh [SwiftPath ...]` | On-demand clean app build and analysis; optional file/directory scope, fails on unused imports or zero analyzed files; never CI, handoff, or style |
| `./Scripts/run-env.sh`, `./Scripts/xcode-runner.sh`, `./Scripts/build-freshness.sh` | Run environment, Xcode execution, generated-input freshness, and `--no-build` stamps for `build` / `test` / `generate` / `run-simulator` / `lint-analyze` / `install-device` / `ci-gate` stamp alignment / `assert-generated-output` idempotence |
| `./Scripts/change-classification.sh` | Sourced by `handoff` / `agent-context` / `agent-push-gate` |
| `./Scripts/ensure-simulator.sh` | Invoked by `test` / `run-simulator` slot setup |
| `./Scripts/check-module-boundaries.sh` | Invoked via `ci-gate --fast` cheap slices (package layering and imports) |
| `./Scripts/check-agent-invariants.sh`, `./Scripts/check-exclusivity-footguns.sh` | Invoked via the style gate only (not `ci-gate --fast`) |
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
(`format-dirs.env` sources `build-inputs.env`; commands source the file they
actually need); generated-output ownership lives in
`Scripts/config/generated-paths.tsv`; diagnostic budgets live in
`Scripts/config/diagnostic-limits.env`; simulator JSON queries live in
`Scripts/simctl_json.py`; cheap CI slices live in `Scripts/config/cheap-slices.txt`. The small helpers under `Scripts/lib/` own shared
mechanics only (tool PATH setup, app build arguments, media conversion/state
sorting, cache pruning, and infrastructure-failure matching); domain-specific
policy remains in the owning command. `Scripts/script_test_selection.py` owns
leaf-script regression families; shared inputs and unknown scripts fall back to
the full suite. It is consumed by `test-scripts.sh`, not a separate gate.

## Toolchain ladder

CI selects the newest installed Xcode automatically (`setup-trinket` logs the
exact version and build; `TRINKET_XCODE_VERSION` pins an older one only for
bisection). Local scripts honor `DEVELOPER_DIR`, otherwise inheriting the Mac's
selected Xcode. [Platform support](../Docs/Platform/ApplePlatformReference.md#platform-support)
owns the supported OS window and how beta validation is used.

`testflight.sh` resolves that local selection once and uses it for verification,
archiving, and export, without changing global `xcode-select`. Its upload receipt
records the exact Xcode version. Use an Apple-supported distribution toolchain;
successful local compilation alone does not establish upload eligibility.

Check [Apple's supported macOS range](https://developer.apple.com/xcode/system-requirements)
as well as the Xcode version. An older Xcode command-line build can succeed even
when its GUI cannot open on a newer macOS. macOS updates do not replace a separately
installed `Xcode-beta.app`; update Xcode itself and then verify command-line selection.

For release verification, use the matching stable installation explicitly without
changing global `xcode-select`. These examples assume the conventional app names;
check the reported version/build and substitute the actual installed path:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./Scripts/handoff.sh --isolate --paths <files...>
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -version
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer ./Scripts/handoff.sh --isolate --paths <files...>
```

The second handoff is prerelease evidence, not release qualification. Confirm the
simulator runtime separately; an existing managed device can use a different OS
than the SDK. Do not reuse `--no-build` products across toolchains. Leave `SDKROOT`
unset unless the owning workflow requires it so SDK and compiler stay aligned.

If the simulator
toolchain is unavailable, run the non-simulator checks that the host supports
(`generate.sh`, generated-output assertion, boundaries, style, and `ci-gate.sh`)
and explicitly report skipped build/test work. Do not claim full verification
until the routed build and test commands pass with the required Xcode toolchain.
