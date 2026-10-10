# Command reference

For the everyday workflow, start at [Scripts](README.md). Open the section for the task; the tables are choices, not a checklist. Script usage and option parsing remain authoritative.

### Development

| Command | Purpose |
|---|---|
| `./Scripts/generate.sh [--assets [--kind art\|music\|sfx\|app-icon\|all]] [--skip-xcodegen]` | Generate the Xcode project without cache reuse and authored derived content (`--assets` also prepares art/music/SFX; `--kind` prepares one asset kind; `--skip-xcodegen` runs content/asset codegen only) |
| `./Scripts/build.sh` | Compile only the app; `--release-device` verifies unsigned iOS Release compilation |
| `python3 Scripts/agent-brief.py --task <concern> [--paths <files...>]` | Stateless concern or file-scoped briefing; `--status` adds scoped changes; prints safeguards, guidance, and read commands. [Quickstart](../Docs/AgentContext/README.md#quickstart) |
| `./Scripts/agent-context.sh --agent --paths …` | Launcher for the same stateless briefing; `--status`, `--smoke`, and `--full` add status, smoke ownership, and plan detail; `--working-tree --allow-broad-scope` is intentional whole-tree work |
| `python3 Scripts/agent-search.py <pattern> --scope <owner>` | Authored-first discovery: matching filenames/counts by default; plain identifiers rank exact stems, filename words/prefixes, then declarations before references outside docs; `--offset`/`--expect` continuations avoid repeats and reject changed results; `--overview` pages owner counts/entry points; `--files` searches filenames (`--mode assets --files` includes binary media names); `--excerpts` for bounded lines, `--mode tests`, `docs`, or `generated` for other surfaces; omissions are explicit |
| `python3 Scripts/agent-diff.py --paths <files...>` | Paged authored diffs plus generated statistics; `--summary` adds generated talent/affix/Homestead record hints with explicit unsupported-format fallback; `--generated` expands generated patches; `--staged` reviews the index; `--full` intentionally reads all units |
| `python3 Scripts/agent-read.py <file>[#anchor] …` | Batch complete Markdown sections with shared flags; `--outline` lists headings or Swift/Python declarations; `--signatures`, `--kind`, and `--match` filter source navigation; repeat `--symbol` for complete declarations; `--lines START:END` also reads shell/config text; large unanchored docs require `--full` |
| `python3 Scripts/agent-search.py --files --glob '<pattern>' --scope <owner>` | Explicit case-sensitive shell filename pattern; `*` crosses directories and patterns without `/` also match basenames; filters and fingerprinted pagination are unchanged; default filename patterns remain regexes |
| `python3 Scripts/agent-search.py <identifier> --related --scope <owner>` | Interleaved declaration/reference/test-file hints within supplied scopes; textual mentions do not establish semantic ownership or coverage; authored source and tests only, with bounded pages |
| `python3 Scripts/agent-search.py '<concern>' --task` | Player-facing concern lookup with source, contract and test pointers plus a routing command; [task index](config/agent-tasks.json) contains navigation only; related lookup supplements mentions with scoped curated test pointers |
| `python3 Scripts/content-inspect.py --id <id>` | Inspect authored content by exact ID, player-facing `--name <text>`, or canonical `--trigger <field>`; `--references` follows parsed fields to schemas, rule anchors, authored Swift and tests; record and reference pages disclose omissions; `--full` expands record fields |
| `node Scripts/agent-worktree.mjs create --task <slug>` | Alternate checkout for an explicitly requested worktree or disposable evaluation, under `.worktrees/<slug>` on `agent/<slug>`; ordinary work stays in the primary checkout on `main` under [AGENTS.md](../AGENTS.md#protect-the-workspace) |
| `./Scripts/new-plan.sh <PlanName>` | Scaffold an active execution plan with an advisory review date under `Docs/Plans/`; completed plans are deleted after updating canonical owners |
| `./Scripts/ensure-ci-tools.sh` | Install pinned XcodeGen, SwiftFormat, SwiftLint, ripgrep, and xcbeautify |
| `./Scripts/update-tools.sh [--apply]` | Report newer SwiftFormat/SwiftLint releases; with `--apply`, bump the pins in `tool-versions.env` (checksummed) and re-install |
| `./Scripts/run-simulator.sh [--isolate] [--agent N] [--inspect]` | Build, resolve the app from the Trinket target’s Xcode build settings (60-second query limit), and launch on a managed simulator (default Trinket Run; `--isolate`/`--agent N` for the isolated pool); `--inspect` holds the lease in a terminal until `stop` or input closes (see [inspection workflow](../Docs/Platform/SimulatorOperations.md#inspection-lease-and-capture)) — also available as `trinket-run` alias via `node Scripts/setup-git-safety.mjs` |
| `./Scripts/promote.sh [--quiet]` | Build once under an isolated lease and install that app only on Trinket Run; build/install failures fail the command (also via `handoff.sh --mirror`) |
| `./Scripts/install-device.sh [--device …]` | Build, install, and launch Trinket on a connected physical iOS device; auto-selects the first paired device |

### Verification

Routine local checks perform no Swift compilation or Simulator/GPU tests.
Use focused static/script checks and handoff. Compiled test wrappers require
CI or a bounded `TRINKET_ALLOW_HEAVY_LOCAL=1` diagnostic under
[execution limits](../Docs/Platform/Verification.md#execution-limits); separate user
approval is not required. Your normal Simulator run remains available and uses
two local build workers.

| Command | Purpose |
|---|---|
| `./Scripts/assert-generated-output.sh [--regenerate] [--assets] [--strict-assets] --idempotent` | Confirm regeneration produces no diff (`--regenerate` runs `generate.sh` first; `--assets` includes art/music/SFX outputs; `--strict-assets` fingerprints full media trees) |
| `./Scripts/build-for-testing.sh` | CI-owned compilation of app/package test schemes for `test.sh … --no-build` runs against CI build artifacts |
| `./Scripts/build-for-testing.sh --app-only` | Build the app and UI test bundles, skipping package test schemes (CI shared build) |
| `./Scripts/test-package.sh [--no-build] [--build-for-testing] [--destination …] [--iterations …] [--run-tests-until-failure] [--include-balance-sweep-tests] [--quiet] [--verbose] <Package> [Package...]` | CI-owned package tests on iOS Simulator; `--destination` allows simulator name/UUID overrides, rejects other platforms, and cannot combine with generic `--build-for-testing`; `--iterations` and `--run-tests-until-failure` support bounded diagnostic repetition; multiple packages emit an aggregate failure summary with retained report paths, `--verbose` expands worker output |
| `./Scripts/test-package-host.sh [--compare-ios] [BattleEngine\|TrinketCore ...]` | Native executed-scope proof; `--compare-ios` checks same-revision iOS timing evidence. Push CI uses qualified native pure logic; manual/nightly retain iOS comparators |
| `./Scripts/test-ci-packages.sh <Package...>` | CI dispatcher: native Engine/Core on pushes, iOS package scopes on manual/nightly runs |
| `gh workflow run diagnostic-ui.yml -f source-run=RUN_ID -f tests='Class/testMethod'` | Focused exact-build UI diagnosis; original conclusions remain unchanged, and absent/incompatible products fail without rebuilding |
| `./Scripts/test.sh unit [--no-build] [--app-only] [--quiet] [--verbose]` | CI-owned package unit suites via the parallel `test-package.sh` owner (`--app-only` is a compile-only app build) |
| `./Scripts/test.sh style [--no-build]` | Run the style gate (format/lint/UI style/API bans/exclusivity/invariants/accessibility IDs) |
| `./Scripts/test.sh performance [--scenario …] [--group …]` | List/run the performance matrix via `performance.sh` selection |
| `./Scripts/test.sh smoke [--no-build]` | CI-owned checked-in smoke registry |
| `./Scripts/test.sh smoke <Class...>` | CI-owned targeted smoke classes |
| `./Scripts/test.sh ui <Target>` | CI-owned exhaustive UI target; bare full suite requires `TRINKET_ALLOW_FULL_UI=1` (CI-owned otherwise) |
| `./Scripts/handoff.sh --isolate --quiet --paths …` | Lightweight local gate; compiled/simulator/generation checks are reported as CI-owned; composition in [Verification.md](../Docs/Platform/Verification.md#gate-composition); `--smoke` reports targeted UI ownership, `--mirror` requires the deliberate heavy-local flag before installing on Trinket Run, `--dry-run` previews the plan, `--final` runs plan closure, `--keep-plan` permits an unfinished plan with `--final`, `--working-tree` opts into whole-tree classification; `--quiet` captures child logs during execution and prints phase outcomes plus bounded failures; successful logs are removed on completion |
| `./Scripts/ci-gate.sh` | CI-owned full gate; composition in [Verification.md](../Docs/Platform/Verification.md#gate-composition) |
| `./Scripts/ci-gate.sh --fast` | Run only the ordered commands in [the cheap-slice registry](config/cheap-slices.txt); skips generation and style |
| `./Scripts/test-scripts.sh [--skip-docs] [--fast] [--paths <file> …]` | Script syntax/regressions with leaf-family selection (`script_test_selection.py`); runs docs unless the caller already checked them |
| `python3 ./Scripts/check-docs.py [--final] [--keep-plan] [--paths <file> …]` | Check links and structure globally; `--paths` scopes final active-plan closure only. Plan expiration is advisory; `check-plans.py` accepts the same flags |
| `./Scripts/check-api-bans.sh` | Banned legacy observation/navigation APIs plus XCTest-outside-UITests migration |

### Headless playthroughs

Manual only; [scope, evidence, and interpretation](../Docs/Platform/HeadlessPlaythroughs.md).
These Simulator careers compile a test product and require a bounded
local diagnostic under [execution limits](../Docs/Platform/Verification.md#execution-limits).
Help remains a read-only query without the opt-in.

```sh
./Scripts/playthrough-sweep.sh --help
TRINKET_ALLOW_HEAVY_LOCAL=1 ./Scripts/playthrough-sweep.sh --scenarios 4 --seed 42 --horizon 2
TRINKET_ALLOW_HEAVY_LOCAL=1 ./Scripts/playthrough-sweep.sh --mode contracts --full-access --horizon 10 --policy setupAware-v1
TRINKET_ALLOW_HEAVY_LOCAL=1 ./Scripts/playthrough-sweep.sh --scenario PlaythroughReports/example/career-0000/scenario.json
TRINKET_ALLOW_HEAVY_LOCAL=1 ./Scripts/playthrough-sweep.sh --replay-bundle PlaythroughReports/example/career-0000
TRINKET_ALLOW_HEAVY_LOCAL=1 ./Scripts/playthrough-sweep.sh --crash-proof
TRINKET_ALLOW_HEAVY_LOCAL=1 ./Scripts/playthrough-sweep.sh --baseline PlaythroughReports/baseline/report.json --scenarios 4 --seed 42 --horizon 2
```

`--output` must name a new directory (default `PlaythroughReports/<timestamp>`).
`--hero`/`--companion` choose starter IDs; `--full-access` simulates content ownership.
`--timeout` bounds each worker in seconds. `--help` lists modes and policies without
acquiring a Simulator. The wrapper acquires isolation, builds the AppState test
product, and supplies explicit worker requests; no nightly automation is created.
Read `report-agent.md` first for bounded findings and recommendations. It links to
complete collections in `report-agent.json`; use `report.html` for human review and
reserve `report.json` plus worker evidence for targeted diagnostics.

### Assets

| Command | Purpose |
|---|---|
| `./Scripts/report-art-memory.sh [--enforce]` | Estimate full-catalog decoded artwork size; `--enforce` fails over budget; interpretation and optional enforcement follow the [art pipeline](../ArtManifest/README.md#decoded-memory-report) |
| `./Scripts/generate.sh --assets` | Also prepare art, music, and SFX (add `--kind <kind>` for one pipeline, `--skip-xcodegen` for codegen only) |
| `./Scripts/ci-assets-gate.sh` | Committed asset integrity without Asset Library |
| `python3 Scripts/asset-library.py --relink --kind art` | Preview unique exact-content matches for missing artwork paths (`--kind app-icon` for packages, or omit `--kind` for all media) |
| `python3 Scripts/asset-library.py --relink --apply --kind art` | Apply the previewed manifest path repairs; run normal media preparation afterward to refresh receipts. Preparation also relinks automatically. |
| `./Scripts/prepare-audio-assets.sh [music\|sfx\|all]` | Validate music/SFX manifests, encode AAC, regenerate `MusicCatalog` / `SFXCatalog` |

### Release

Requested local release and TestFlight execution use `TRINKET_ALLOW_HEAVY_LOCAL=1`
for their required deploy suites; doctor and dry-run need no opt-in. See
[Release](../Docs/Platform/Release.md) for complete examples and prerequisites.

| Command | Purpose |
|---|---|
| `./Scripts/setup-testflight.sh` | Install local Ruby/Bundler/Fastlane tooling with locked gems; [configuration](../Docs/Platform/Release.md#one-time-testflight-setup) stays outside Git |
| `./Scripts/testflight.sh [--doctor \| --dry-run \| --resume RUN] [--config FILE] [--notes FILE] [--cloud-sync YES\|NO] [--timeout SECONDS]` | Verify a clean checkout, archive/sign, upload, and confirm internal TestFlight availability; retain evidence for recovery; no Git mutations or review submission |
| `./Scripts/test-deploy.sh [--mode smoke\|ui] [--no-build]` | CI-owned full deploy suites (deliberate local diagnostic opt-in required); `--mode smoke` is an optional canary |
| `./Scripts/release.sh [--version X.Y.Z] [--since-tag TAG] [--skip-tests] [--dry-run] [--no-tag]` | Preview or execute a release (`--version` pins semver, `--since-tag` sets the notes range, `--skip-tests` skips deploy verification, `--no-tag` commits without tagging) |

### Diagnostics

| Command | Purpose |
|---|---|
| `python3 ./Scripts/test-timing.py report` | Show per-suite wall-time history and hotspots from test runs |
| `python3 ./Scripts/test-timing.py show --last 10` | Show recent run IDs, outcomes, targets, and result-bundle availability without hotspot output |
| `python3 ./Scripts/test-timing.py record --mode … --run …` | Record one timing entry from a result bundle |
| `python3 ./Scripts/test-timing.py assert-budget` | Fail when recorded timings exceed the configured budget |
| `./Scripts/performance.sh [--scenario ID] [--group GROUP] [--list]` | CI-owned manual app + battle performance matrix (`performance.yml` dispatch); `--list` prints scenarios/groups, default is one pass |
| `./Scripts/record-time-profiler.sh --output <path.trace> [--time-limit 8s] [--attach Trinket] [--all-processes] [--print-command]` | Host Time Profiler of the Trinket process (no `xctrace --device`; `--all-processes` is opt-in and slow; `--print-command` prints without recording) |
| `./Scripts/agent-watch-ci.sh [--ref <branch>] [--sha …] [--scope standard\|exhaustive] [--poll-seconds <n>] [--verbose]` | Poll a hosted CI run for a commit; prints failed jobs and annotations when red |
| `./Scripts/ci-diagnostics.sh [RESULTS_DIR]` | Aggregate the current diagnostics session (`--reset` clears it) |
| `./Scripts/ci-diagnostics.sh --cleanup [--keep] <RESULTS_DIR>` | Remove completed successful invocations individually after staging; expire failures and unfinished output after 24 hours; `--keep` explicitly retains the results directory until released |
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
| `./Scripts/restore-ci-test-products.sh [--downloaded] -- <rebuild-command> [arguments...]` | Validate transferred UI products and rebuild incompatible or missing artifacts on the receiving CI runner |
| `python3 Scripts/build-metadata.py <action> <results> <fingerprint>` | Build-environment metadata owned by build/test wrappers; `--help` lists identity options |
| `./Scripts/stage-ci-test-artifact.sh` | Archive Products + build stamps/environment metadata in a tar file for CI `--no-build` test jobs |
| `./Scripts/agent-push-gate.sh` | Internal pre-push generation completeness; invoked automatically by pre-push, not a manual post-commit step |
| `./Scripts/ci-diagnostics.sh --stage-artifacts <RESULTS_DIR> <ARTIFACT_DIR>` | Stage structured artifacts outside the source results tree and its ancestors, adding raw failure evidence only when needed |
| `./Scripts/ci-diagnostics.sh --stage-gate-artifacts <RESULTS_DIR> <ARTIFACT_DIR>` | Stage the gate transcript and script regression logs within fixed upload size limits |
| `python3 Scripts/report-exhaustive-ci.py <jobs.json>` | Report actual advisory shard conclusions from paginated GitHub job results; invoked by the exhaustive summary job |
| `./Scripts/lint-analyze.sh [SwiftPath ...]` | On-demand clean app build and analysis; optional file/directory scope, fails on unused imports or zero analyzed files; never CI, handoff, or style |
| `./Scripts/run-env.sh`, `./Scripts/xcode-runner.sh`, `./Scripts/build-freshness.sh` | Run environment, Xcode execution, generated-input freshness, and `--no-build` stamps for `build` / `test` / `generate` / `run-simulator` / `lint-analyze` / `install-device` / `ci-gate` stamp alignment / `assert-generated-output` idempotence |
| `python3 Scripts/verify.py --dry-run --paths …` | Structured routing/verification implementation behind handoff; preview and execution use the same argument lists |
| `./Scripts/ensure-simulator.sh` | Invoked by `test` / `run-simulator` slot setup |
| `./Scripts/check-module-boundaries.sh` | Invoked via `ci-gate --fast` cheap slices (package layering and imports) |
| `./Scripts/check-agent-invariants.sh`, `./Scripts/check-exclusivity-footguns.sh` | Invoked via the style gate only (not `ci-gate --fast`) |
| `./Scripts/check-artwork-budget.sh`, `./Scripts/release-notes.sh` | Invoked via `ci-gate` cheap slices |
| `./Scripts/check-build-cache-paths.sh`, `./Scripts/check-testplan-sync.py`, `./Scripts/check-links.py`, `./Scripts/check-plans.py` | Invoked via `test-scripts.sh` / `check-docs.py` |
| `./Scripts/check-unused-assets.py`, `./Scripts/check-accessibility-ids.py`, `./Scripts/check-ui-style.py` | Invoked via style / asset gates |
| `./Scripts/prepare-assets.sh`, `./Scripts/prepare-art-assets.sh`, `./Scripts/prepare-app-icon.sh` | Invoked via `generate.sh --assets` |
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
policy remains in the owning command. `Scripts/script_test_selection.py` reads
Python modules' `SCRIPT_INPUTS` and owns
shell mappings and full-suite exceptions; see [script regression ownership](README.md#script-regression-ownership).
Unknown inputs fall back to the full suite. The selector is consumed by
`test-scripts.sh`, not a separate gate.

## Toolchain ladder

Required push CI and default manual/performance runs select the exact Xcode
version and product build in [ci-xcode.json](config/ci-xcode.json). A missing pin
fails setup rather than silently changing the compiler. Nightly CI and manual
`toolchain=latest` runs validate the newest installed Xcode independently; they
cannot reuse the required toolchain's verification. Local scripts honor
`DEVELOPER_DIR`, otherwise inheriting the Mac's selected Xcode.

Promote a newer build in `ci-xcode.json` only after `toolchain=latest` CI proves
that exact build's Metal readiness, app/smoke, package tests and device Release
compilation. Commit the pin and verify its push; a marketing version alone cannot
distinguish two betas. Confirm that every relevant job reports the same product
build; mixed runner-image results cannot qualify a pin. [setup-ci-xcode.py](setup-ci-xcode.py) reads the product
version plist, logs the exact build, and exports job-local `DEVELOPER_DIR` without
changing global `xcode-select`.
Changes to the setup script or required pin select app/smoke and all package checks.

Jobs that need Metal first compile and link a small shader for the simulator SDK.
If that fails, setup attempts Apple's component download up to three times with
bounded waits under the same runner user and selected Xcode as the build, then
repeats the shader check. Download success or an installed
status alone cannot establish readiness. An unavailable catalog fails setup with
its logs intact; it does not count as game/build verification. This avoids
mistaking a runner image rollout or missing beta catalog for a game regression.

[Platform support](../Docs/Platform/ApplePlatformReference.md#platform-support)
owns the supported OS window and how beta validation is used.

`testflight.sh` resolves that local selection once and uses it for verification,
archiving, and export, without changing global `xcode-select`. Its upload receipt
records the exact Xcode version. Use an Apple-supported distribution toolchain;
successful local compilation alone does not establish upload eligibility.

Check [Apple's supported macOS range](https://developer.apple.com/xcode/system-requirements)
as well as the Xcode version. An older Xcode command-line build can succeed even
when its GUI cannot open on a newer macOS. macOS updates do not replace a separately
installed `Xcode-beta.app`; update Xcode itself and then verify command-line selection.

For release artifacts, use the matching stable installation explicitly without
changing global `xcode-select`. These examples assume the conventional app names;
check the reported version/build and substitute the actual installed path:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild -version
```

Version queries and lightweight handoff do not compile Swift or validate a runtime.
Use CI evidence or a bounded local diagnostic under
[Verification](../Docs/Platform/Verification.md#execution-limits) for those claims.
Beta compile/runtime results remain prerelease evidence, not release qualification.
Confirm the simulator runtime separately; an existing managed device can use a different OS
than the SDK. `--no-build` rejects missing metadata or incompatible build environments; CI also
checks the producing commit and rebuilds incompatible transferred products. Leave `SDKROOT`
unset unless the owning workflow requires it so SDK and compiler stay aligned.

If the simulator toolchain is unavailable, run lightweight path-scoped handoff
and report the CI-owned build/test evidence as pending. Generation and the full
CI gate are not toolchain-free fallbacks: content generation can compile the
ability-inventory tool, and the full gate requires the heavy-verification route.
Do not claim full verification until the routed compiled checks have passed with
the required toolchain.

### Output retention

`python3 Scripts/cleanup-outputs.py --dry-run` lists expired known output paths,
protected paths, and allocated-byte totals without writing a report. `--apply`
removes those candidates. Add `--experiments` for the three abandoned build
experiments (CPU optimization, BalanceSweep refactor, Labyrinth host tests). This
explicit option checks for open files and active owners rather than relying on
directory timestamps, which can change when a checkout moves.
Current app, package, device, and reusable agent caches, pinned tools, generated
freshness state, release receipts, signed archives, and symbols are preserved.

Successful logs disappear after consumers finish. Failure and comparison evidence (including agent evaluations under
`.DerivedData/AgentEvaluationResults/`)
expires after 24 hours; timing entries expire individually. Live owners, leases,
locks, and explicitly kept output prevent deletion. Unknown owner state or an
unreadable process inventory prevents cleanup. Symlinks are never followed.
Expiry runs opportunistically through the existing tools, with no background job.
`TRINKET_OUTPUT_MAX_AGE_HOURS` overrides the default for a deliberate investigation.

```sh
python3 Scripts/cleanup-outputs.py --keep BalanceSweepReports/investigation
python3 Scripts/cleanup-outputs.py --release BalanceSweepReports/investigation
```

Keep/release accepts existing paths in the known repository output roots.
`ci-diagnostics.sh --cleanup --keep` uses the same persistent keep marker.
`TRINKET_KEEP_REPORTS=1` keeps a wrapper's output until released;
`TRINKET_CLEANUP_TEST_ARTIFACTS=0` only defers cleanup through downstream consumers.
Custom destinations outside these roots stay caller-owned. Temporary guidance
receipts are scoped to this checkout and expire after one day of inactivity.
Hosted diagnostic/timing artifacts expire after one day; reusable build-product
artifacts retain their seven-day consumer window.
