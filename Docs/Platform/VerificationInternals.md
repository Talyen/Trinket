# Verification implementation

Hosted execution, qualification, caching, and gate composition. Ordinary agent
work uses [Verification](Verification.md#confidence-ladder); read this document
when changing or diagnosing the verification machinery.

## Native pure-logic qualification

Hosted iOS/native qualification gates native activation. Push and standard verified CI run
`BattleEngine`, `TrinketCore`, and qualified `TrinketContent` natively after that qualification agrees. Persistence
and State independently verify saves and AppState on iOS, and smoke keeps the real simulator/app path. Native
execution must complete every independently discovered function and parameterized
case without skips or issues; a positive aggregate count is insufficient.
Activation follows the selected build's `native_packages` in
[ci-xcode.json](../../Scripts/config/ci-xcode.json). Add a package only after exact-build
qualification succeeds; unqualified fallback builds retain that package's iOS tests.
DesignSystem's packaged color and contrast checks stay on iOS.

Qualification, exhaustive, latest-toolchain and nightly runs keep the full iOS package scopes and compare native
Engine/Core/Content executed identities, expanded parameterized case counts, and results
on the same revision. Native comparators run in separate 25-minute hosted jobs,
with three minutes reserved for diagnostics. The iOS lane transfers compact
successful execution proof bound to repository, commit, run, attempt, package and
selected Xcode identity; missing, incomplete or mismatched proof fails comparison.
Retain a complete comparator proof even if another package in its shard fails.
Unrelated unit failures do not skip requested parity; those unit failures still fail
`CI OK` independently.
Partial reruns must include the producing iOS lanes as well as native comparators;
an earlier attempt's proof cannot qualify a new attempt.
Requested parity remains part of `CI OK`. Standard checks reused by an ordinary
manual follow-up do not request a new comparator; `qualification`, latest-toolchain
and exhaustive-pilot runs bypass that reuse. The manual
`qualification` scope runs only those three native/iOS comparator lanes; it does not
establish app, UI, Release, or other-package proof. Qualification mismatches fail
the run. Structured proof uses the versioned
[Swift Testing event stream](https://github.com/swiftlang/swift-testing/blob/main/Documentation/ABI/JSON.md),
not console glyphs or an incidental terminal-summary format.

## Execution deadlines

Standard build, package, UI, asset, and unsigned Release jobs record an absolute
execution deadline in their first step, reserving three minutes before the GitHub
job timeout for diagnostic classification and upload. The shorter generation/style
gate reserves two minutes. The command supervisor includes simulator
preparation and serial package work; per-command Xcode watchdogs also cap themselves
against the remaining deadline, preserving a short manifest-finalization allowance.
CI allows five minutes per cold boot (local default: 150 seconds), based on
observed boots finishing after the old four-minute limit. Simulator recovery
admits another boot only when its full watchdog fits
within the setup recovery window: six minutes for standard lanes, twelve for the
downloaded qualified release runtime, which has demonstrated a successful erase/boot
recovery. An exhausted window fails before consuming the test budget.
`TRINKET_CI_SIMULATOR_SETUP_WINDOW_SECONDS` selects that admission window. Local recovery
retains its existing attempts. Timeouts remain failures and emit structured receipts. Supervisors terminate only
their own process groups; existing simulator guest/lease cleanup remains in force.

Combined build/smoke/exhaustive jobs allow 55 minutes so the existing 30-minute UI
watchdog can run after compilation and smoke; ordinary build/smoke jobs allow 40.
The Battle package shard allows 30 minutes (other package shards allow 25), and
exact-build UI diagnostics allow 30. Each keeps the three-minute diagnostic reserve.

CI Smoke and the explicitly selected qualified release journeys enable XCTest's
five-minute per-method execution limit. Hosted UI preparation records memory and
swap counters after boot to distinguish resource pressure from test execution. Their observed baseline methods finish
below 136 seconds. A stuck method must fail and retain evidence before consuming
the entire batch watchdog; this does not classify a product timeout as infrastructure.
Other FullUI, Soak and performance runs retain their existing execution allowances.
After a failure on an ownership-verified simulator, disposable CI retains up to
four recent Trinket app IPS crash reports (2 MiB each), validating their bundle ID.
It does not run Xcode sysdiagnose: that collection has stalled result finalization
after all six Smoke methods passed. Local and foreign app reports are excluded.

The infrastructure rerun helper checks every failed concrete job and vetoes
product assertions, compiler errors and other gate failures. The derived CI OK
failure does not block that classification; rerunning failed jobs still rechecks
CI OK. The watch command attempts one such recovery, not a blanket test retry.

## Gate composition

Local handoff selection and completion are owned by
[Verification](Verification.md#confidence-ladder). This section describes hosted
gates and the machinery used by explicit diagnostic/release routes.

| Gate | Composition |
|---|---|
| `ci-gate.sh` | Pinned-tool ensure, generation and idempotence, assert against HEAD, full-tree style, module boundaries, script syntax and regression tests, API-ban policy (incl. XCTest migration), release-note validation; compiled artwork-budget behavior belongs to FeatureSupport package tests |
| `ci-gate.sh --fast` | Only the ordered commands in [the cheap-slice registry](../../Scripts/config/cheap-slices.txt) |
| `ci-assets-gate.sh` | Check committed prepared assets and manifest/resource integrity without source masters |
| `test-deploy.sh` | Full CI/release evidence with exact-commit hosted proof reuse and local phase checkpoints; local `ui`/`smoke` execution uses the deliberate heavy-local flag and diagnostic limits, while `--mode beta` consumes hosted proof without a local heavy run. [Release recovery](Release.md#options-and-recovery) owns checkpoint identity and invalidation |
| Main CI | Post-push on `main` (no pull-request workflow): path filter, generation/style/full script regressions, app build with smoke on the same runner, and package unit for product changes |
| Clean analysis | Explicit local `lint-analyze.sh [SwiftPath ...]` cleanup using a clean app build; unused imports fail the command; never part of CI or handoff |
| Device Release compilation | Nightly and standard manual CI run unsigned device Release compilation concurrently with independent build/smoke and package checks, with a 30-minute job budget and reserved diagnostic time; failures block that run’s `CI OK`, ordinary pushes skip it. Signing/export/upload remain TestFlight responsibilities. |
| Nightly exhaustive | Scheduled or manually dispatched exhaustive UI with all registered classes on one runner; advisory, never blocks `CI OK` |
| Performance diagnostics | Manual `performance.yml` dispatch with a validated group/repetition selection; never part of routine local or push verification |

Nightlies validate the newest installed Xcode even when the commit is unchanged:
runner images and Apple component catalogs can change independently of source.
Required pushes use an explicitly qualified toolchain; admission, preference and Metal readiness follow the
[toolchain ladder](../../Scripts/Reference.md#toolchain-ladder). Latest-toolchain
manual runs cannot reuse qualified-toolchain checks; exhaustive UI remains advisory.

`Smoke.xctestplan` and `FullUI.xctestplan` are disjoint. [Release](Release.md#local-testflight-deployment)
owns beta/full-release policy and known-failure handling;
[TestFlight evidence](#testflight-evidence-and-reuse) owns execution and reuse.
Before pushing a release candidate, `test-deploy.sh --compile-only` can expose
test-target compiler failures without executing the portfolio. Targeted UI filters
require a non-skipped execution for every requested class or method; an absent or
entirely skipped filter fails.

### Generation and package selection

Generation in full gates is intentionally uncached: CI and hosted handoff
invoke `generate.sh` directly, including repeated generation for
idempotence. Lightweight local handoff and pre-push do not regenerate. Only the
`prepare_generated_inputs` freshness path inside build/test wrappers skips
generation, and only when content, project, and asset inputs are all unchanged.

The build job compiles app test products once, runs smoke on that runner, and
publishes products for exhaustive UI. Exhaustive UI runs every registered FullUI
class on one runner with one product transfer. It restores the exact-run product
archive from the retained build artifact and rebuilds when that transfer is missing
or cannot be validated. Incremental build caches are separate from product transfers.
Pushes select owning packages for edits confined to their `Tests/` directories.
Source and shared test-support edits also select transitive dependents. Shared build
inputs, package-manifest changes, unknown ownership, and missing dependency evidence
select the full portfolio. Narrow selection requires all manifests to match the
reviewed layout fingerprints in `ci-path-filter.py`; any changed manifest retains
full coverage until its target/input ownership is reviewed and its fingerprint
deliberately updated. Tests and handoff never refresh these fingerprints.
Rewound or divergent push history, unknown comparison status, and incomplete file
inventories select all gates because merge-base comparisons can omit removed changes.
Standard manual and scheduled runs retain full package coverage; partial push
verification does not substitute for it. Native qualification follows the
[executed-scope contract](#native-pure-logic-qualification). Dispatch
`scope=qualification` for the focused same-revision comparators, or
`scope=exhaustive-pilot` to bypass standard reuse and exercise the complete
portfolio plus inline UI. Normal exhaustive dispatches retain standard reuse.

Upfront full runs execute FullUI on the build/smoke runner and report its outcome
through a separate advisory status job, eliminating product transfer. Follow-up
full dispatches with prior standard proof retain the transfer/reuse path.

### Runner admission and package isolation

[Hosted workflows](../../.github/workflows/tests.yml) own admission limits and job
membership. Verified runs stage short logic jobs before widening package concurrency,
avoiding startup starvation. Failed/skipped logic keeps conservative admission but
still runs remaining coverage; its failure independently fails `CI OK`.
Qualification/latest retain the complete iOS matrices. Retune with whole-run timing.

Package jobs compile/test in separate cache tenants. Core, Persistence, AppState,
FeatureSupport and BattleFeature retain independent failure/retry boundaries;
packages do not download app products. AppState separates purchase contracts from
MainActor-heavy save/career work so that work cannot consume the purchase suite's
one-minute deadline. Filtered invocations require complete result-bundle evidence;
ignored filters, skipped purchase methods, or missing cases fail.
Native compiler state stays separate from iOS comparator state. Disposable runners
skip local age-pruning scans while retaining explicit pruning, result retention,
and simulator/guest ownership safeguards.

### Hosted proof reuse

Manual runs queue behind current branch verification without allocating a waiting
runner. They reuse successful standard checks only for the exact commit and branch,
with actual successful build/smoke, gate, and all unit jobs proving the full package
portfolio in their successful test steps, plus one available product artifact from
the same commit and attempt as its successful producing build step. Skipped jobs,
ambiguous or expired products, and unreadable evidence fall back to ordinary
verification. Asset verification is reused only with its own successful job evidence;
standard manual device Release compilation still runs. New pushes supersede obsolete branch runs.
See [ci-reuse.py](../../Scripts/ci-reuse.py) for the proof contract. Exact shards, artifact contracts, cache inputs, and remaining advisory
job behavior belong to the checked-in workflows ([tests.yml](../../.github/workflows/tests.yml) and
related workflow files); update this guide only when the verification policy
changes.

Product-only consumers use a separate exact-commit archive contract. A successful
archive-producing build step and its same-attempt artifact can transfer products
before other checks finish, including after a UI failure. Receiving runners still
validate commit and build environment and execute every requested journey; transfer
never certifies gate, unit, smoke, parity, or release results. Device Release builds
use their own incremental cache namespace and still invoke optimized compilation.
For controlled qualified-journey timing, dispatch `release-verification.yml` with
`fresh-evidence=true` and the exact source `commit`; prior passed journey records are
neither consumed nor saved by that comparison. Compare the same runtime and executed
selectors, and separate first attempts, reruns, setup, transfers and queue time.
Prepared asset integrity runs the same source-free byte and manifest checks on
Linux; that gate does not reserve a Mac or install Xcode and Swift lint tools.

### Build products and cache identity

`build.sh` compiles only the app. Test products transfer separately from incremental
compiler caches, preserving executable permissions, runtime shaders and artwork.
Reuse requires matching Xcode/SDK, architecture policy, configuration, test fingerprint,
and source snapshot; CI additionally requires the same commit. Missing, legacy or
incompatible metadata/products rebuild and validate again. Invalidate the product
family's old stamp before compilation so failed work cannot appear reusable.

The [metadata owner](../../Scripts/build-metadata.py) fingerprints source edits and
deletions, authored test plans, generated project and schemes. Markdown, compiler
caches and Xcode user state are excluded. Change cache-version prefixes when layouts
change. Assess cache value using restore, build and save durations together.

CI package caches restore/save only each shard's declared tenants under
`.DerivedData/host/<package>` or `.DerivedData/packages/<package>`, plus compiler
input timestamps; dependencies build inside that owner. Native-only lanes omit
simulator products. The `package-v2`/`package-native-v2` namespaces exclude older
broad archives, while retaining toolchain/platform identities and prefix reuse.
Package selection namespaces keys so qualification subsets cannot replace a full
shard's immutable cache. Restored/final metadata-only footprint reports follow
[output retention](../../Scripts/Reference.md#output-retention). Allocated bytes do
not measure transfer compression, cache effectiveness or game RAM; the reporter
never deletes hosted caches.

Combined gates omit a repeated API-ban slice only after style has passed; standalone
cheap slices retain the full registry. Unit mode delegates to the package runner
and its timing/diagnostic records.

Cheap slices include read-only [localization freshness](Localization.md). Relevant
handoff, locked integration and pre-push checks block on pending work without AI
calls. Existing CI builds verify extraction and compiled languages; FullUI captures
localized screenshots/hierarchies. Use actual compiled and rendered evidence for
layout, fonts and packaging.

## Player profile execution

[Player coverage](PlayerCoverage.md#ci-and-profiles) owns devices, scenarios, cadence
and acceptance. These mechanics preserve that scope when provisioning or diagnosing
`player-coverage.sh` and its native-settings helpers.

### Runtime and product preparation

Xcode 27's command-line downloader rejects pre-26 runtimes
([FB24836279](https://developer.apple.com/forums/thread/847134)). CI exports iOS 18.0
using Xcode 26.6 on `macos-26`, transfers it with one-day retention, and imports it
on the verified Xcode 27 runner. Compilation/tests still use the verified toolchain.
The disposable compatibility runner removes eligible preinstalled iOS images before
transfer and the archive after import. `ci-runtime-cleanup.py` validates the complete
inventory, preserves busy/non-iOS images and retains receipts. Only read-only
inventory gets one timeout retry; deletion errors fail with the
`ios18-runtime-cleanup` phase. Both build and test request the iOS 18 profile.

Other profiles install the requested minimum runtime when absent: Duo's required
minor, otherwise the major's `.0`. Use Apple's `arm64` variant on Apple silicon and
`universal` on Intel; forcing universal can reject an available Apple-silicon release.
Recheck runtime/device compatibility after preparation; failed provisioning fails
the requested aggregate while independent device portfolios continue.

Reuse only compatible exact-commit products. Missing/incompatible products rebuild,
using warm caches when available. One architecture's products can serve multiple
profiles. Executions remain serial under their owned simulator lease and retain the
build's results directory/stamps; logs and verdicts identify that directory.

### Native settings and failure evidence

Native text-size setup verifies the requested value, avoids reapplying unchanged
sizes and restores the original once after the device's profiles, including failures.
Reduce Motion uses native Settings and restores after each class. Both methods verify
the actual SwiftUI environment; a launch argument alone is insufficient.

Settings navigation starts from the root/sidebar, uses named destination controls,
and reacquires controls after navigation/mutation. The helpers handle offscreen rows,
search dismissal and the retained Motion screen. Preparation failures attach native
Settings screenshots/hierarchy and a `[coverage prerequisite]` marker; dependent
product assertions must not proceed as if preparation succeeded.

Run each of seven native audit types separately, excluding only the opt-in diagnostic
label. Collect all findings before restoring stop-on-failure; every product violation
still fails. A native-audit timeout gets one immediate retry; a repeated timeout fails.
Each attempt retains profile, screen, audit type, runtime, issue/error attachments and
foreground captures. Scroll reward actions into view before auditing and restore
reachability afterward because the audit may move the viewport.

Publish each profile's log/status before starting the next. Keep failed profiles,
soak, careers and recovery verdicts individually visible while independent checks
continue; screenshot export failure retains the original bundle. [Evidence limits](PlayerCoverage.md#evidence-and-remaining-gates)
still distinguish automated execution from visual, hardware and live-service proof.

## TestFlight evidence and reuse

Routine beta verification uses green exact-commit CI, actual Smoke, and qualified
high-risk journeys selected against the last available beta. FullUI remains
nightly/on-demand; `testflight.sh --full-ui` and `release.sh` retain the complete
portfolio. Use `--mode smoke` for the optional local canary. Beta selectors batch
by Smoke/FullUI plan with StoreKit configuration and exact-method execution proof;
formal FullUI release verification retains per-class phases.

Successful journey inputs and failed-class markers are retained in a hosted cache.
Reuse compares committed app, resources, configuration, tooling, shared helpers,
selected tests, Xcode/SDK, architecture, simulator profile, and verification
settings. Every expected UI case must execute once and pass before evidence is
saved. A failure revokes prior evidence for its class and selects that class again
on the next candidate. Pending selectors share one invocation per test plan;
complete passed selectors remain checkpointed if another selector fails.
Unknown shared helpers invalidate conservatively.

Deployment consumes the exact-commit workflow's successful qualified job and
proof artifact. Its receipt must match the release commit, Xcode, SDK, host
architecture, and qualified simulator profile, including runtime build 23C54 for
iOS 26.2, and cover every critical journey. Runtime build changes invalidate
cached journey evidence even when the displayed OS version is unchanged.
Before checkpointing a UI batch, its completed xcresult must report that same
guest OS build; an installed runtime listing alone does not establish execution.
The standard CI `CI OK` gate must also succeed for that commit. Smoke is
proven by the complete qualified hosted classes, or an actual standard CI Smoke
execution; a skipped standard Smoke job does not force unrelated package reruns. Missing, failed, cancelled, unreadable, expired, or mismatched proof
blocks upload; there is no automatic local test fallback. Resume retains signed
artifacts while awaiting CI. Signing keys and App Store Connect credentials stay
on the Mac; simulator CI needs no Apple distribution credentials.

Hosted warm builds restore source timestamps only for byte/size/mode-identical inputs
in the same checkout/toolchain context; changed, new, missing and symlinked inputs
stay fresh. [Timestamp restoration](../../Scripts/build-source-times.py)
owns that optimization; refresh its manifest only after a successful build.

`verification.json` checkpoints successful package suites and UI selectors, with
phase timings and local or hosted evidence. Resume runs only missing phases for
the same clean commit, checkout, toolchain/SDK, architecture, and simulator
profile. A changed identity invalidates the checkpoints; a failed phase never
becomes a checkpoint. Missing build products are rebuilt before remaining tests.

## Scoped static routing

Local and hosted routing read package/generation inputs and generated-output roots
through `Scripts/internal/source_ownership.py`, backed by the existing authored
registries. CI shard membership must cover that package inventory exactly once.
`internal/path_matching.py` keeps the two existing wildcard dialects explicit:
local `matches` permits a wildcard to span separators, while hosted `glob_match`
keeps a single star within its component and uses `**` for recursive paths.
Sharing ownership facts does not combine local budgets with hosted qualification
or relax incomplete-evidence fallbacks.

Local documentation checks select edited files, inbound links to changed or deleted
targets, and affected structural owners. Checker changes select the full gate.
Unscoped/hosted checks retain full link and structural coverage. Local localization
checks validate changed Swift and affected catalogs plus their consumers; shared
localization configuration, glossary, review and tool changes retain full coverage.
These scoped passes do not establish repository-wide freshness.

Markdown routes to documentation checks even beneath script or manifest roots.
For executable script changes, handoff passes the same path scope to the script
runner. Registered leaf families run their owning and consumer regressions;
documentation checks and their direct integration tests share a focused suite;
shared infrastructure, unknown scripts and unscoped CI run the full suite. Script
syntax follows the supplied path scope; build-input alignment remains full-tree.
Local cheap slices use the registry's declared input scopes; CI retains the
complete registry. Family
ownership follows [script regression ownership](../../Scripts/README.md#script-regression-ownership):
Python and shell consumers share `Scripts/config/script-regressions.tsv`; the
selector retains explicit full-suite exceptions. Update the input's registry row
when a leaf gains a consumer. Do not narrow shared helpers from filename
similarity alone.
