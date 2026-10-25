# Command reference

Follow [AGENTS.md](../AGENTS.md#route-and-read) for the everyday workflow.
The examples below select a task; use a command's `--help` where supported for its
complete syntax. Script parsing and configuration remain authoritative. Low-level
wrappers are for diagnostics/tooling, subject to [execution limits](../Docs/Platform/Verification.md#execution-limits).

### Development

| Example | Purpose |
|---|---|
| `./Scripts/generate.sh` | Generate authored derived content and the Xcode project; `--assets` includes media, `--skip-xcodegen` selects content/asset codegen only |
| `./Scripts/build.sh` | Compile the app; `--release-device` selects unsigned iOS Release compilation |
| `python3 Scripts/agent-brief.py --status --read --paths <files...>` | Read scoped safeguards and ownership; `--full --read` expands linked contracts, `--task <concern>` selects indexed concern depth |
| `python3 Scripts/content-inspect.py --id <id>` | Inspect content; `--name`, `--trigger`, and `--references` support rule/caller investigation |
| `node Scripts/agent-worktree.mjs create --task <slug>` | Create an isolated task checkout from committed local main |
| `node Scripts/agent-worktree.mjs integrate` | Land under the shared lock; [review, recovery and cleanup](../Docs/Platform/Release.md#isolated-chat-workflow) own its preconditions |
| `node Scripts/agent-worktree.mjs cleanup` | Preserve deliverables and remove this clean integrated worktree, retaining its branch |
| `node Scripts/agent-worktree.mjs evidence [path...]` | Preserve task-local evidence, or print its durable directory |
| `node Scripts/agent-worktree.mjs remove --task <slug>` | Legacy removal from primary; refuses dirty/unmerged tasks and ignored files |
| `./Scripts/new-plan.sh <PlanName>` | Scaffold an execution plan under [Plans](../Docs/Plans/README.md) |
| `./Scripts/ensure-ci-tools.sh` | Install pinned tools |
| `./Scripts/update-tools.sh --apply` | Update tool pins and installation; omit `--apply` for a report |
| `./Scripts/run-simulator.sh --isolate --inspect` | Hold a managed build/launch/inspection session; [simulator operations](../Docs/Platform/SimulatorOperations.md#inspection-lease-and-capture) own targeting and recovery |
| `./Scripts/promote.sh` | Build once in isolation and install on Trinket Run; no launch by default |
| `./Scripts/install-device.sh --device <name-or-id>` | Build/install/launch on selected physical hardware; `--release` selects optimized testing |

Briefing and handoff default to the complete task against `main`: commits plus
dirty files, deletions and both rename endpoints. `--base <ref>` selects another
comparison base, `--paths` selects an iteration, and `--working-tree` selects dirty
files only. Worktree creation accepts `--base` only for a user-specified alternative.
Never omit task paths from final verification. Integration's `--reviewed-main <commit>`
records combined-main review; `--keep-plan` retains intentionally unfinished plans.

For simulator play, humans omit `--isolate`; `trinket-run` is the alias installed by
`setup-git-safety.mjs`. Agents use the managed pool. `--agent N` requires an existing
parent lease. `--unlocked` uses the separate [Debug gameplay fixture](../Docs/Platform/Purchases.md#local-development);
arguments after `--` reach the app. Native input/capture follows the
[simulator skill](../.agents/skills/ios-simulator/SKILL.md).

### Optional retrieval

Use `rg`, file reads and Git diffs. The briefing is the sole required retrieval
command. Legacy helpers remain available through their own help. Caller hints are
lexical, not resolved Swift call graphs; concern indexes are navigation, not coverage proof.

### Localization

| Example | Purpose |
|---|---|
| `python3 Scripts/localization.py run` | Translate and independently review pending entries; resumes matching work |
| `python3 Scripts/localization.py job` | Prepare manual work for another AI tool and print its finish command |
| `python3 Scripts/localization.py check --paths <files...>` | Read-only scoped gate |

[Localization](../Docs/Platform/Localization.md#agent-workflow) owns review,
fingerprints, interruption and compatibility aliases. Only explicit local `run`
invokes AI; hooks, builds and CI validate without AI calls.

### Verification

[Verification's confidence ladder](../Docs/Platform/Verification.md#confidence-ladder)
owns handoff selection, examples, local/hosted scope and visual review. Start with
`./Scripts/handoff.sh --quiet`; `--dry-run` previews without execution.
For final plan checks, `--final` requires closure unless `--keep-plan` explicitly
retains unfinished work. Integration supplies that final static gate.

| Diagnostic/tooling entry point | Purpose |
|---|---|
| `./Scripts/assert-generated-output.sh` | Compare generated paths with HEAD; `--idempotent` regenerates and checks stability, `--regenerate` regenerates before HEAD comparison. Follow [generation policy](../Docs/Platform/Verification.md#generated-project-consistency) |
| `./Scripts/build-for-testing.sh --app-only` | Compile app/UI test products; omit `--app-only` to include package schemes. `--reuse` requires valid source/toolchain/product metadata |
| `./Scripts/test-package.sh <Package...>` | iOS package tests; help covers suite filters, destinations and bounded repetition |
| `./Scripts/test-package-host.sh --compare-ios <Package...>` | Native executed-scope proof and iOS comparison under [qualification](../Docs/Platform/VerificationInternals.md#native-pure-logic-qualification) |
| `./Scripts/test-ci-packages.sh <Package...>` | Hosted dispatcher for qualified native or iOS package scopes |
| `gh workflow run diagnostic-ui.yml -f source-run=RUN_ID -f tests='Class/testMethod'` | Exact-build diagnosis; `mode=smoke`, `ui`, or `soak`. Missing/incompatible proven products fail without rebuilding |
| `./Scripts/test.sh style` | Format, lint, UI style, API bans, exclusivity, invariants and accessibility IDs |
| `./Scripts/test.sh unit` / `smoke` / `ui <Target>` / `performance` | Low-level test routes; full UI needs its separate opt-in and execution scope |
| `./Scripts/ci-gate.sh` | Full hosted gate; `--fast` selects only [cheap slices](config/cheap-slices.txt) |
| `./Scripts/test-scripts.sh --paths <files...>` | Scoped script syntax/regressions; docs run unless already checked by the caller |
| `python3 Scripts/check-docs.py` | Full links/structure gate; `--paths` scopes edited/inbound documents, `--final` checks plan closure. `check-plans.py` retains global metadata validation |
| `./Scripts/check-api-bans.sh` | Legacy API and XCTest-outside-UITests policy |

### Headless playthroughs

[Headless playthroughs](../Docs/Platform/HeadlessPlaythroughs.md) owns scenario,
replay, isolation and interpretation. Careers compile a test product and use a
Simulator; bounded local diagnostics follow [execution limits](../Docs/Platform/Verification.md#execution-limits).
Help acquires no lease and needs no opt-in:

```sh
./Scripts/playthrough-sweep.sh --help
TRINKET_ALLOW_HEAVY_LOCAL=1 ./Scripts/playthrough-sweep.sh --scenarios 4 --seed 42 --horizon 2
TRINKET_ALLOW_HEAVY_LOCAL=1 ./Scripts/playthrough-sweep.sh --replay-bundle PlaythroughReports/example/career-0000
TRINKET_ALLOW_HEAVY_LOCAL=1 ./Scripts/playthrough-sweep.sh --crash-proof
```

Help lists mode, party, policy, access, scenario, baseline and worker options.
`--output` requires a new directory. Read `report-agent.md` first, then complete
analysis in `report-agent.json`; `report.html` is for human review and `report.json`
plus worker evidence for targeted diagnostics. Weekly/manual careers follow
[Player coverage](../Docs/Platform/PlayerCoverage.md#ci-and-profiles).

### Assets

| Example | Purpose |
|---|---|
| `./Scripts/generate.sh --assets` | Prepare media; `--kind` selects art, music, sfx, app-icon or all |
| `./Scripts/report-art-memory.sh --enforce` | Check estimated full-catalog decoded size; omit enforcement for a report. [Interpretation](../ArtManifest/README.md#decoded-memory-report) |
| `./Scripts/ci-assets-gate.sh` | Committed asset integrity without source masters |
| `python3 Scripts/asset-library.py --relink --kind art` | Preview unique exact-content repairs within repo `AssetSources/`; `--apply` writes them. Prepare media afterward to refresh receipts |
| `./Scripts/prepare-audio-assets.sh music` | Focused audio preparation; also accepts `sfx` or `all` |

### Release

[Release](../Docs/Platform/Release.md) owns prerequisites, authorization, recovery
and complete examples. These entries do not authorize publishing.

| Example | Purpose |
|---|---|
| `./Scripts/setup-testflight.sh` | Install locked local deployment tools; [configuration](../Docs/Platform/Release.md#one-time-testflight-setup) stays outside Git |
| `./Scripts/testflight.sh --doctor` | Read-only prerequisites; `--dry-run` previews. Actual beta upload requires exact-commit hosted proof |
| `./Scripts/test-deploy.sh --compile-only` | Compile every test target without release certification; help lists beta/smoke/ui modes and checkpoint options |
| `./Scripts/release.sh --dry-run` | Preview release artifacts; isolated preparation uses `--no-tag`, then tags the verified integrated commit under [the release procedure](../Docs/Platform/Release.md#produce-release-artifacts) |

Requested local deploy suites and `testflight.sh --full-ui` use the heavy-local
flag. Default beta consumes hosted proof and never falls back to local tests;
doctor and dry-run need no opt-in.

### Diagnostics

| Example | Purpose |
|---|---|
| `python3 Scripts/test-timing.py report` | Suite timing/hotspots; `show --last 10` lists runs, `record` imports a result and `assert-budget` enforces configured limits |
| `./Scripts/performance.sh --list` | List the manual performance matrix; scenario/group selection and measurements follow the [playbook](../Docs/Platform/PerformanceInvestigationPlaybook.md) |
| `./Scripts/record-time-profiler.sh --output <path.trace> --time-limit 8s` | Host process Time Profiler; all-process capture is opt-in, never `xctrace --device` |
| `python3 Scripts/profile-device.py --device <UDID> --duration 30` | Physical CPU/hitch capture with retained matching symbols; [profiling](../Docs/Platform/PerformanceInvestigationPlaybook.md#physical-device-profiling-over-wi-fi) owns build/install and interpretation |
| `python3 Scripts/build-symbols.py --archive PATH --ipa PATH --receipt PATH` | Validate symbol UUIDs/payload and preserve a complete release backup |
| `./Scripts/testflight.sh --verify-symbols BUILD` | Read-only Apple symbol-status check; success requires confirmation |
| `./Scripts/agent-watch-ci.sh --sha <commit>` | Follow hosted checks and report failures; does not authorize a push |
| `./Scripts/ci-diagnostics.sh <RESULTS_DIR>` | Aggregate diagnostics; `--cleanup --keep` deliberately retains output. [Retention](#output-retention) owns expiry |
| `./Scripts/change-budget.sh --paths <files...>` | Advisory surface signals; counts are not justification quotas |
| `./Scripts/prune-derived-data-cache.sh` | Prune safe old build artifacts |
| `python3 Scripts/report-profile-inventory.py --output /new/inventory.json` | Metadata-only legacy profiling XML inventory; no hashing, compression or deletion |
| `python3 Scripts/report-cache-footprint.py report --packages BattleEngine --native-only true --output /new/cache.json` | Report selected/unrelated package tenant allocation without reading build contents |
| `python3 Scripts/simulator-idle-cleanup.py --check` | Preview human-session idle cleanup; [operations](../Docs/Platform/SimulatorOperations.md#optional-human-session-idle-cleanup) owns opt-in installation/removal |
| `./Scripts/balance-sweep.sh` | Headless battle balance sweep |

### Internal helpers

Find an internal helper through its calling command, hook or workflow. These are
maintenance pointers, not additional workflow steps. Helpers without dedicated help:

| Helper | Owner / interface |
|---|---|
| `package-diagnostics.py [--verbose] <worker-output-dir> <packages...>` | Package runner's deduplicated diagnostics |
| `restore-ci-test-products.sh [--downloaded] -- <rebuild-command> [arguments...]` | Receiving runner's product validation/rebuild |
| `stage-ci-test-artifact.sh` | Runtime products, stamps and environment metadata archive |
| `report-exhaustive-ci.py <jobs.json>` | Advisory conclusions from paginated job results |
| `ci-diagnostics.sh --stage-artifacts <RESULTS_DIR> <ARTIFACT_DIR>` | Structured evidence outside source results and ancestors; `--stage-gate-artifacts` adds bounded gate/script logs |
| `check-staged-project.sh`, `agent-push-gate.sh`, `validate-commit-msg.sh` | Git hooks; push gate is automatic, never a manual post-commit step |
| `run-env.sh`, `xcode-runner.sh`, `build-freshness.sh`, `ensure-simulator.sh` | Build/test isolation, execution, freshness and stamps |
| `lint-analyze.sh [SwiftPath ...]` | Optional clean app analysis; unused imports and zero analyzed files fail; outside CI/handoff/style |

All helper paths are under `Scripts/`. `verify.py --dry-run --paths …` exposes
handoff's structured plan; `build-metadata.py --help` describes build identity.
Gate composition and checker owners live in [Verification](../Docs/Platform/Verification.md#style-and-boundary-ownership)
and [VerificationInternals](../Docs/Platform/VerificationInternals.md#gate-composition).
Media helpers are invoked by `generate.sh --assets`; content codegen by `generate.sh`.

| Configuration | Owner |
|---|---|
| Tool pins | `tool-versions.env` |
| Build/package/generation roots and test plans | `build-inputs.env`; `format-dirs.env` sources it for formatting roots |
| Generated output ownership | `config/generated-paths.tsv` |
| Diagnostic budgets / simulator queries | `config/diagnostic-limits.env` / `simctl_json.py` |
| Cheap gates / regression selection | `config/cheap-slices.txt` / [script regression registry](README.md#script-regression-ownership) |

`lib/` owns shared mechanics; domain policy stays with its command. Unknown
regression inputs fall back to the full suite through `script_test_selection.py`.

## Toolchain ladder

Required push CI and default manual/performance runs select an explicitly qualified
Xcode version/product-build pair in [ci-xcode.json](config/ci-xcode.json). The top-level
`version`/`build` is preferred; `qualified_builds` lists the approved alternatives
in fallback order. A runner without the preferred build selects the first installed
qualified pair; no qualified pair fails setup. Runner image/version, installed
identities and selection reason appear in logs and the job summary. Nightly CI and manual
`toolchain=latest` runs validate the newest installed Xcode independently; they
cannot reuse the required toolchain's verification. Local scripts honor
`DEVELOPER_DIR`, otherwise inheriting the Mac's selected Xcode.

Manual `toolchain=latest` runs can set `xcode-build` to an exact candidate product
build (for example `27A9275`). Every job must find that build installed or fail;
the selector never substitutes the newest beta or changes the verified pin.
Leave the field blank for normal newest-installed validation.

Admit or prefer a newer build in `ci-xcode.json` only after exact-candidate `toolchain=latest` CI proves
that exact build's Metal readiness, app/smoke, package tests and device Release
compilation. Commit the qualified list and verify its push; a marketing version alone cannot
distinguish two betas. Confirm that every relevant job reports the same product
build; mixed-build results cannot qualify a candidate. Ordinary verified CI may
use different qualified builds across runners during a rollout; caches and product
transfers still require their actual selected compiler identity.
[setup-ci-xcode.py](setup-ci-xcode.py) reads the product
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

Version queries and local automatic/static handoff do not compile Swift or
validate a runtime. Compilation and tests remain CI-owned; use the handoff report
to identify deferred obligations. The [single focused diagnostic exception](../Docs/Platform/Verification.md#single-focused-local-diagnostic)
and expressly requested local diagnostic/release selectors require
`TRINKET_ALLOW_HEAVY_LOCAL=1` under [Verification](../Docs/Platform/Verification.md#execution-limits).
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
Shared Xcode/host/device caches, pinned tools, generated freshness state, release
receipts and authoritative signed archives/symbols are preserved. Idle tenants under
`.DerivedData/runs/` and legacy `Packages/*/.build/` expire after three days without writes, including their build
products and intermediates; `TRINKET_RUN_MAX_AGE_DAYS` overrides this window.
Recent writes, live owners, leases, keep markers and open files protect a tenant.
Unavailable process/open-file inventories fail closed. Expiry shares the simulator
slot allocation lock so it cannot remove a newly claimed agent cache. Arbitrary
legacy build directories outside those explicit roots remain untouched. The balance
CLI is rebuildable; retiring its inactive SwiftPM cache can make its next run slower.

`--primary` selects this repository's primary checkout from a task worktree.
Add `--resources` for the more expensive full verification and 24-hour expiry of
ready TestFlight duplicate working copies. Review the dry run before applying;
[release retention](../Docs/Platform/Release.md#options-and-recovery) owns eligibility,
permanent artifacts and recovery. Reports distinguish protected releases and unknown
state from eligible duplicate allocated bytes. Regular opportunistic cleanup does
not hash all release archives.

`python3 Scripts/report-build-size.py --archive /path/Trinket.xcarchive --output /new/evidence`
records universal app/catalog sizes, encoding groups and source identity when the
archive has an adjacent receipt. `--app /path/Trinket.app` inspects an existing build
instead. Unsigned device Release CI retains this compact inventory for 14 days.
These are neither device delivery sizes nor measured resident RAM.
An expressly requested local diagnostic may add `--export-thinned` for a device
size report using existing signing credentials, `TRINKET_ALLOW_HEAVY_LOCAL=1` and
the shared host lane. It never uploads or requests provisioning updates; exported
products are temporary and only the size report/log is retained. Failed export
leaves universal inventory and diagnostics without claiming thinning succeeded.

`report-profile-inventory.py` defaults to the external artifact store's `profiles`
root; `--root` selects another existing capture root. The output must be new and
outside that root. Raw trace XML and unknown XML remain separate from named export
candidates. Adjacent traces/provenance and retention controls are metadata leads,
not proof of reproducibility or idle ownership. The report always declares zero
bytes eligible for deletion. Verify capture identity, a regeneration recipe and
consumer/owner state before a later migration; preserve needed evidence first.

CI package caches restore/save only each shard's declared package tenants under
`.DerivedData/host/<package>` and, for simulator lanes,
`.DerivedData/packages/<package>`, plus compiler input timestamps. Dependencies
build inside those tenants. Native-only lanes omit simulator products. Scoped
`package-v2`/`package-native-v2` namespaces prevent restoring the old broad archives;
the first run rebuilds, while subsequent runs retain existing toolchain/platform
identity and prefix reuse. Package selection also namespaces keys, so qualification
subsets cannot replace a full shard's immutable cache. Restored/final metadata-only footprint reports are
retained for 14 days. Allocated bytes do not measure compressed transfer size,
cache effectiveness or game RAM. No hosted caches are deleted by the reporter.

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
Hosted logs, bounded failure diagnostics, compact timing, and native qualification
evidence retain a 14-day window. The repository Actions retention setting must be
at least 14 days or GitHub caps the workflow requests. Check it with
`gh api repos/Talyen/Trinket/actions/permissions/artifact-and-log-retention`;
changing the setting affects future evidence and cannot restore expired objects.
Large reusable build-product and iOS runtime artifacts retain a one-day consumer
window; full performance traces also expire after one day. Missing or expired
products follow the existing rebuild/validation policy.
