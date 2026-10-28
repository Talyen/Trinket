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
| `node Scripts/agent-worktree.mjs integrate` | Land under the shared lock and clean the finished checkout; `--keep-worktree` retains it for ongoing work. [Review and recovery](../Docs/Platform/Development.md#isolated-chat-workflow) own preconditions |
| `node Scripts/agent-worktree.mjs cleanup` | Preserve deliverables and remove this clean integrated worktree, retaining its branch |
| `node Scripts/agent-worktree.mjs evidence [path...]` | Preserve task-local evidence, or print its durable directory |
| `node Scripts/agent-worktree.mjs remove --task <slug>` | Legacy removal from primary; refuses dirty/unmerged tasks and ignored files |
| `./Scripts/new-plan.sh <PlanName>` | Scaffold an execution plan under [Plans](../Docs/Plans/README.md) |
| `./Scripts/ensure-ci-tools.sh` | Install pinned tools |
| `./Scripts/update-tools.sh --apply` | Update tool pins and installation; omit `--apply` for a report |
| `./Scripts/run-simulator.sh --isolate --inspect` | Hold a managed build/launch/inspection session; [simulator operations](../Docs/Platform/SimulatorOperations.md#inspection-lease-and-capture) own targeting and recovery |
| `./Scripts/promote.sh` | Build once in isolation and install on Trinket Run; no launch by default |
| `./Scripts/install-device.sh --device <name-or-id>` | Build/install/launch on selected physical hardware through host admission and the shared Xcode runner; `--release` selects optimized testing |

Handoff defaults to the complete task against `main`: commits plus dirty files,
deletions and both rename endpoints. Briefing requires an explicit scope; use
`python3 Scripts/agent-brief.py --base main` for that same complete task.
`--base <ref>` selects another comparison base, `--paths` selects an iteration, and `--working-tree` selects dirty
files only. Briefing `--paths` requires individual repository-relative files, not
directories; use `rg --files` to identify files before selecting the intended scope.
Worktree creation accepts `--base` only for a user-specified alternative.
For a concrete local diagnostic, add `--diagnostic-package <package>`,
and `--diagnostic-suite <suite>` to a scoped briefing. For a visual inspection,
add `--visual-command`. Briefing uses `CODEX_THREAD_ID` for the host owner; pass
`--owner <thread-id>` to override it or when it is unavailable. It uses the same
`CODEX_HEAVY_LANE_HELPER` override as the local admission fallback. These print the
bounded outer command without running it or granting broader authorization.
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
| `python3 Scripts/test-timing.py report` | Suite timing/hotspots; `show --last 10` lists runs, `record` imports a result and `assert-budget --mode <mode> --max-wall <seconds>` checks recorded wall time |
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

### Resource reports

`python3 Scripts/report-build-size.py --archive /path/Trinket.xcarchive --output /new/evidence`
records universal app/catalog sizes, encoding groups and receipt source identity.
`--app /path/Trinket.app` inspects an existing build instead. An expressly requested
local diagnostic may add `--export-thinned` using existing signing credentials,
the heavy-local flag and shared host lane. It never uploads or requests provisioning
updates. Exported IPA catalogs are inspected inside temporary scope; native size
reports, compact encoding groups, logical sizes and logs survive. Failed exports
retain universal inventory/diagnostics without claiming thinning succeeded. These
are local Xcode estimates, neither certified App Store delivery sizes nor RAM.

`report-profile-inventory.py` defaults to the external artifact store's `profiles`
root; `--root` selects another capture root. Choose a new output outside that root.
It separates raw trace XML, unknown XML and named export candidates and always
reports zero bytes eligible for deletion. Metadata, adjacent traces and keep/owner
controls do not prove reproducibility or inactivity: verify capture identity,
regeneration and consumers before a migration, preserving needed evidence first.

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

`python3 Scripts/report-storage.py` reports primary checkout storage, worktree
Git state and guarded cleanup summaries without mutation. Add `--details` for
individual cleanup decisions or `--evidence-details` for task-level evidence sizes.
Clean status and ancestry do not prove inactivity;
APFS allocation estimates may share extents and are not reclaimable-space promises.

This matrix owns artifact lifetimes and cleanup eligibility. The executable owners
are [output retention](internal/output_retention.py),
[release-copy validation](../Docs/Platform/Release.md#options-and-recovery),
[evidence preservation](../Docs/Platform/Development.md#evidence-and-cleanup) and the
producing hosted workflows. Age alone never proves that an artifact is disposable.

| Artifact | Default lifetime / review point | Removal conditions |
|---|---|---|
| Successful test/gate invocation bundles, reports and raw logs | Until consumers finish | Producer cleanup removes successful output after staging; explicit keeps remain protected |
| Historical failure, orphan and comparison evidence, including agent evaluations | Review after 24 hours (`TRINKET_OUTPUT_MAX_AGE_HOURS`) | Automatic producer cleanup writes `.retention-review.json`; permanent deletion of unique evidence requires exact-batch approval |
| Local timing entries and temporary guidance receipts | 24 hours per timing entry; one day of inactivity for checkout-scoped guidance receipts | Existing expiry removes eligible entries/receipts individually |
| Idle task compiler scratch under `.DerivedData/runs/` and legacy `Packages/*/.build/` | One day without writes (`TRINKET_RUN_MAX_AGE_DAYS`) | Cleanup checks ownership, leases, keeps and open files under the simulator allocation lock; preserves tenant products and evidence |
| Compiler scratch and agent products retired at task creation | Same idle-cache window | Known agent app/package/host intermediates and product directories; preserves package checkouts, diagnostics and shared compilation caches; no-build requests reject missing products |
| Shared primary/device compiler scratch and build products | Same idle-cache window | Managed producers register a lifecycle lease; cleanup also rejects open files and active or uninspectable Apple build/debug processes. Device products require independently verified, exact binary and dSYM copies from a successful profile |
| Successful IPA inspection / thinned-export scratch | Until inspection consumers finish | Scoped temporary cleanup retains compact validation/size proof; failed inspection output and explicit keeps remain available |
| Ready or exported TestFlight duplicate working copies | 24 hours after verified preservation and last receipt write | Deployment-locked hash/UUID/receipt validation; exported runs remain resumable from the verified backup; unbacked, unknown, mismatched, active or kept copies remain protected |
| Authoritative uploaded archive, IPA, matching symbols and provenance; deployment receipts and failed build-number reservations | Indefinite | Release working-copy cleanup never removes these records |
| Task deliverables and preserved evidence snapshots | Retained; routine successful static reports expire after seven days | Later task creation journals classified reports and respects active worktrees and keep markers. Legacy reports require an integrated task record, matching commit and report path; failed, visual, release and unclassifiable evidence remains protected |
| Raw device traces, matching symbols and explicitly retained derived exports | Caller-owned / explicitly kept | No general profile sweep; preserve raw evidence and verify any proposed derivative deletion separately |
| Hosted logs, bounded diagnostics, compact timing, size/cache reports and native qualification evidence | 14 days | Workflow expiry, subject to GitHub's repository retention cap |
| Exact qualified release proof | 30 days | [Release verification workflow](../.github/workflows/release-verification.yml) owns this exception |
| Hosted reusable build products, iOS runtime transfers and full performance traces | One day | Consumer window only; missing/expired products follow existing rebuild/validation policy |

All local removal preserves live or unknown owners, leases, locks, keep markers
and unavailable process/open-file inventories. Symlinks are never followed.
Shared Xcode/host/device caches, pinned tools, generated freshness state and
arbitrary legacy build directories are outside ordinary expiry. Process queries
inspect only this invocation/direct owner and scoped open files. Cleanup is
explicit or opportunistic through existing tools, with no background job.

`python3 Scripts/cleanup-outputs.py --dry-run` lists known candidates, protection
reasons and allocated bytes without writing a report; `--apply` applies that
inventory's policy. From a task checkout, `--primary` selects the primary checkout.
The balance CLI is rebuildable, so retiring its eligible SwiftPM cache can make
the next run slower. Add `--experiments` only for the named CPU optimization,
BalanceSweep refactor and Labyrinth host-test experiments; open-file/owner checks
still apply rather than trusting directory timestamps.

For compiler scratch only, use `--dry-run --primary --intermediates-only
--receipt PATH`; the compact receipt records `.DerivedData/Retention/` decisions.
Add `--products` to include known agent app, package and host products. Task
creation performs that bounded maintenance automatically.
`--release-duplicates-only` verifies at most one backed-up ready or exported run per
call; add `--all-release-duplicates` for all candidates. Before a local
TestFlight deployment takes its lock, it automatically runs that full verified
duplicate pass against the primary checkout; a busy or ambiguous owner defers it.
`--resources` includes the more expensive release duplicate inventory;
review its dry run before applying. Normal opportunistic cleanup does not hash
all release archives. [Release](../Docs/Platform/Release.md#options-and-recovery)
owns exact validation and recovery mechanics.

Task creation also runs a bounded, incremental pass over inactive task snapshots.
On macOS it losslessly compresses eligible old text and clones exact duplicate
files at matching paths within a branch when filesystem support and byte/metadata
checks permit. Candidates are 1–128 MiB files last modified at least seven days ago;
each pass attempts at most four. Verification reports stay outside this path;
native result, archive, symbol and trace contents may only use exact clones, never
compression or conversion.
Paths remain unchanged; active, open, kept, recently modified, ACL-bearing and
unknown evidence is skipped. Per-file allocated-byte estimates can overstate real
free-space gains on APFS. Existing unclassified routine evidence remains retained.

```sh
python3 Scripts/cleanup-outputs.py --keep BalanceSweepReports/investigation
python3 Scripts/cleanup-outputs.py --release BalanceSweepReports/investigation
```

Keep/release accepts existing paths in known repository output roots.
`ci-diagnostics.sh --cleanup --keep` uses the same persistent marker.
`TRINKET_KEEP_REPORTS=1` keeps wrapper output until released;
`TRINKET_CLEANUP_TEST_ARTIFACTS=0` defers cleanup through downstream consumers.
Custom destinations outside these roots remain caller-owned.

Check GitHub's repository cap before relying on a workflow's requested window:
`gh api repos/Talyen/Trinket/actions/permissions/artifact-and-log-retention`.
A lower repository cap shortens retention; changing it affects future evidence
and cannot restore expired objects.
