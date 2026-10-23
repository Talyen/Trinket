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

| Gate | Composition |
|---|---|
| `handoff.sh` (static route) | Locally: scoped style, fast selected script regressions, docs, cheap static slices and selected prepared-asset integrity; reports content/project generation, compilation, package and UI work as CI-owned; local cheap slices use declared input scopes |
| `ci-gate.sh` | Pinned-tool ensure, generation and idempotence, assert against HEAD, full-tree style, module boundaries, script syntax and regression tests, API-ban policy (incl. XCTest migration), release-note validation; compiled artwork-budget behavior belongs to FeatureSupport package tests |
| `ci-gate.sh --fast` | Only the ordered commands in [the cheap-slice registry](../../Scripts/config/cheap-slices.txt) |
| `ci-assets-gate.sh` | Check committed prepared assets and manifest/resource integrity without Asset Library |
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

Generation in full gates is intentionally uncached: CI and an explicitly enabled
heavy handoff invoke `generate.sh` directly, including repeated generation for
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

Verified runs admit the short Engine/Core jobs alongside build/smoke, gate and
Release, then allow up to five remaining package jobs after that logic stage
succeeds. A skipped or failed logic stage retains the three-job cap; remaining
coverage still runs after a logic failure, which independently fails CI OK.
This avoids both initial runner starvation and a permanently restricted tail.
Qualification/latest retain their complete iOS matrices. Retune admission with
whole-run timing if runner capacity changes. Package jobs restore separately keyed incremental state and byte-verified source
timestamps in their per-package DerivedData tenants, then always invoke compilation/testing
so changed inputs rebuild. Disposable standard/release runners disable local output
age-pruning scans; explicit cache pruning, result retention and simulator/guest
ownership checks remain in force. Core, Persistence, and AppState have separate jobs: a failed
app-state invocation does not repeat passed save tests when rerunning failed jobs.
FeatureSupport and BattleFeature also run separately, preserving passed support
coverage when battle verification needs a retry. AppState runs its seven purchase
contracts and the remaining suites in disjoint invocations on the same runner.
The purchase suite retains its one-minute limit; heavy MainActor save/career work
cannot consume that deadline while purchase tasks wait to resume. Filtered package
runs require complete result-bundle evidence: an ignored inclusion/exclusion, a
skipped purchase method or missing case evidence fails the job.
They do not download the app product archive. Native-only Engine/Core jobs restore
only native compiler state in a separate namespace, retaining simulator state for
the iOS comparator lanes. Cache identity uses setup-trinket’s selected Xcode
version/build without launching another version-query process.

### Hosted proof reuse

Manual runs queue behind current branch verification without allocating a waiting
runner. They reuse successful standard checks only for the exact commit and branch,
with actual successful build/smoke, gate, and all unit jobs proving the full package
portfolio in their successful test steps, plus an available product
artifact. Skipped jobs, expired products, and unreadable evidence fall back to ordinary
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

Ordinary `build.sh` compiles only the app; it does not produce reusable test
bundles. CI keeps app incremental build state in its warm cache and transfers only
runtime products, build stamps, and versioned environment metadata in a tar archive to preserve executable permissions. Compiler-only Swift module metadata is omitted from transfers; runtime shaders and artwork remain intact.
Local reuse requires matching Xcode, SDK, architecture policy, configuration, and
test fingerprint as well as the build's source snapshot. The snapshot detects
edits and deletions, includes all authored test plans plus generated project/shared
scheme configuration, and excludes compiler caches, Xcode user state, and Markdown
so those changes do not force a rebuild. The selected Xcode product version
is read directly from its installed version plist when available, avoiding a
potentially stalled `xcodebuild -version` process; SDK and source checks still run. Missing or legacy metadata requires
a rebuild. CI additionally requires the same commit; incompatible or missing
transfers are discarded and rebuilt on the receiving runner, then validated again.
Builds invalidate prior stamps for their product family before compilation so a
failed build cannot leave partially updated products marked reusable.
The cache uses a new version prefix when its layout changes. Compare the hosted
restore, build, and save step durations together when assessing cache value;
a cache hit alone is not evidence of a faster run.

Combined gates run API bans once: standalone style includes them, and cheap
slices omit that check only after successful style verification. Standalone
cheap slices retain the full registry. Unit mode delegates directly to the
package runner; per-package timing records own its diagnostic evidence.

The cheap slices include read-only [localization coverage and freshness](Localization.md).
Every relevant handoff, locked integration and pre-push blocks on its pending
queue; builds and hooks do not invoke AI. Existing CI app builds separately verify
compiler-extracted keys and compiled language bundles. FullUI owns localization
screenshots and accessibility hierarchy evidence. The read-only localization gate
does not prove compilation, fonts, layout or archive language packaging; use the
handoff report for actual selected compiled checks.

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
architecture, and qualified simulator profile, and cover every critical journey.
The standard CI `CI OK` gate must also succeed for that commit. Smoke is
proven by the complete qualified hosted classes, or an actual standard CI Smoke
execution; a skipped standard Smoke job does not force unrelated package reruns. Missing, failed, cancelled, unreadable, expired, or mismatched proof
blocks upload; there is no automatic local test fallback. Resume retains signed
artifacts while awaiting CI. Signing keys and App Store Connect credentials stay
on the Mac; simulator CI needs no Apple distribution credentials.

Hosted warm builds also retain a source-timestamp manifest. Before Xcode runs,
CI restores an input's prior timestamp only when its current bytes, size, mode,
and checkout/toolchain context match the cached record. Changed, new, missing,
or symlinked inputs stay fresh. This avoids treating every file in a fresh Git
checkout as changed while retaining Xcode's normal build/dependency checks.
The manifest is refreshed only after a successful build and saved with DerivedData.

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
