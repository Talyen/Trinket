# Verification and CI

This guide owns when to choose a verification route, gate composition, test
tiers, and style ownership. Exact commands and flags live in
[verification commands](../../Scripts/Reference.md#verification) and each script's usage/option parsing.
Test authoring conventions live in [Testing.md](Testing.md). Isolation and IDE
setup: [SimulatorOperations.md](SimulatorOperations.md).

## Confidence ladder

Choose the cheapest route that answers the question at hand. Gate composition
is listed below; test authoring and tier ownership follow [Testing.md](Testing.md).
Compiled routes run in CI or an expressly requested local diagnostic under the
[local execution limits](#execution-limits). Routine local handoff stays lightweight.

| Task | Route | Use |
|---|---|---|
| Package behavior | `test-package.sh <Package>` | Focused iteration in the owning package |
| All package behavior | `test.sh unit` | All package schemes; no app-level unit target |
| App compilation | `test.sh unit --app-only` | Compile coverage for app-level Swift changes |
| Task handoff | `handoff.sh --isolate --quiet --paths <files...>` | Required agent gate; add `--smoke` for changed interaction wiring |
| Focused interaction | `test.sh smoke <Class>` / `test.sh ui <Class>` | Existing journey, within the local limits below |
| Gate-only check | `ci-gate.sh` / `ci-gate.sh --fast` | Full gate or cheap slices; neither runs unit/UI tests |
| Local canary | `test-deploy.sh --mode smoke` | Optional human confidence run |
| Release confidence | `release.sh` / `test-deploy.sh` | Requested release verification; local execution requires explicit opt-in |
| Performance investigation | `performance.sh` | Ad hoc measurement under the performance playbook |

Path-scoped commands normalize in-repository absolute paths to repository-relative
files and reject directories or paths outside the repository.

Run `./Scripts/agent-context.sh --agent --status --paths <files...>` after touched paths
are known. Use `--working-tree --allow-broad-scope` only for an intentional whole-tree scope. The
briefing separates ownership constraints from behavior references and prints the handoff
route; rerun it when requested work or an encountered fix crosses into another
owner. The final path list is the union of requested work and every explicitly
adopted fix, not the task's initial path list.

For shared enum or API reviews, include relevant committed changes in the
comparison scope and follow downstream consumers beyond the dirty files. Include
app compilation in the CI evidence when package checks do not compile those
consumers; it catches exhaustive-switch failures in unchanged code. An expressly
requested local compile diagnostic uses the same isolated app-only route under
the execution limits below. Whole-tree dirty-path routing alone does not cover
relevant committed changes.

Markdown routes to documentation checks even beneath script or manifest roots.
For executable script changes, handoff passes the same path scope to the script
runner. Registered leaf families run their owning and consumer regressions;
documentation checks and their direct integration tests share a focused suite;
shared infrastructure, unknown scripts and unscoped CI run the full suite. Script
syntax follows the supplied path scope; build-input alignment and the handoff's
cheap slices remain full-tree. Family
ownership follows [script regression ownership](../../Scripts/README.md#script-regression-ownership):
Python modules declare `SCRIPT_INPUTS` beside their tests; the selector retains
shell mappings and full-suite exceptions. Update the consuming module's metadata
when a Python-tested leaf gains a consumer. Do not narrow shared helpers from
filename similarity alone.

## New iOS release readiness

Use this at a major iOS/Xcode adoption boundary, not for every UI change.
[Platform support](ApplePlatformReference.md#platform-support) owns the supported
window and beta/stable policy; [toolchain selection](../../Scripts/Reference.md#toolchain-ladder)
owns command setup. Record host macOS, Xcode build, SDK, runtime, device, app revision, and
observed outcomes so beta evidence is distinguishable from release evidence.

1. During betas, compile with the candidate SDK and run existing focused journeys
   on its runtime. Review relevant release notes, deprecations, native component
   changes, and useful new APIs.
2. Inspect Play, Collection, Homestead, Options, a detail sheet, and a battle on
   the new runtime: safe areas, floating chrome, legibility, hit targets, card
   input, dismissal, and meaningful feedback. Check icon appearances through the
   [icon workflow](ApplePlatformReference.md#app-icon). Retain PD-014's scope.
3. Check save/relaunch, an interrupted battle, and purchase/restore using existing
   fixtures and the owning integration routes. Check physical audio/haptics only
   on a device; use the [feedback reference](../../.agents/skills/apple-design/performance-and-feedback.md).
   Synthetic StoreKit/CloudKit results do not replace their release prerequisites.
4. When CI first selects a new major toolchain,
   verify runner availability, generation idempotence, app
   Release compilation, and routed package/smoke checks. Exercise the retained
   previous-major runtime as well as the newest one, including both branches
   of any new availability checks. Confirm the leased simulator's runtime: a
   cached simulator name or the build SDK alone is not runtime coverage.
5. Complete existing release verification and report missing runtime/device or
   service prerequisites as gaps. Platform readiness does not authorize publishing.

Use existing isolated runners and tests. Do not add a permanent full-device matrix
or snapshot suite merely to record an OS transition. When a supported runtime is
unavailable, report it; do not claim the support window has been verified.

## Generated project consistency

`./Scripts/generate.sh` runs XcodeGen through the pinned wrapper with a fresh
cache location on every invocation. Command flags live in
[verification commands](../../Scripts/Reference.md#development), generation
inputs in `Scripts/build-inputs.env`, and the content/asset workflow in
[content and manifests](../AgentContext/content-and-manifests.md). When changed
paths select generation, the full handoff plan regenerates, then forces a second
generation to check idempotence. Routine local handoff reports that work as
CI-owned; it does not execute generation or prove idempotence. Generate the
outputs needed for an authored-input change through the owning workflow; broad
freshness verification remains CI-owned.

Edit the authored inputs, never the generated project or processed outputs.
When the staged project is stale, run `./Scripts/generate.sh`, review the
project diff, and stage the canonical output with its inputs. Staged-project
validation and push safeguards follow
[Release.md](Release.md#local-hooks-and-push-discipline); pre-push checks committed
output completeness, while CI runs forced generation and compares its result
with committed output.

## Local simulator budget

### Choosing UI verification

Routine local verification uses scoped formatting/lint, accessibility and boundary
checks, selected fast script regressions, and documentation checks. It performs no
Swift compilation, simulator boot, UI tests, performance measurements, or broad
asset/project generation. `handoff.sh --isolate --quiet --paths <files...>` reports
heavy checks as deferred to CI; a local PASS is not compile or interaction proof.

CI owns package tests, app compilation, critical smoke, nightly/manual FullUI,
generation/idempotence, and manual performance measurements. Review hosted results
after the next authorized push. Keep missing CI evidence explicit in handoff; do
not run the hosted suites on the laptop to fill that gap.

Changed interaction wiring and accessibility identifiers require the relevant
hosted journey evidence. `--smoke` selects the routed smoke owner for the handoff
report; ordinary local execution still defers it. Apply the [keep/drop rubric](Testing.md#ui-keep-drop-rubric)
when there is no existing owner. A visual change needs appropriate visual evidence;
passing compilation or interaction tests alone do not establish visual polish.

### Execution limits

- Local script regressions default to one worker; handoff uses the fast selected
  script families. CI runs complete script coverage with its worker pool.
- Agents do not set `CI`/`GITHUB_ACTIONS` or the heavy-local override to bypass
  this policy. Controlled script fixtures may simulate those environments with
  stubbed commands; they must not start real builds or simulators.
- An expressly requested local test diagnostic may use
  `TRINKET_ALLOW_HEAVY_LOCAL=1` with a focused test selector. The wrappers limit
  package and UI concurrency; this is not routine verification.
- Bare FullUI additionally requires `TRINKET_ALLOW_FULL_UI=1`; preserve the
  deliberate full-suite distinction even for an authorized diagnostic.
- Full deployment test suites are CI-owned. Deliberate local pre-release tests
  require the same explicit heavy-local diagnostic opt-in; do not bypass them
  silently or claim release readiness without their required evidence.

### Local play

The normal `run` alias and `run-simulator.sh` continue to build and launch the
game for the user. They do not run test suites. Local Debug simulator compilation
uses the native architecture and two Xcode build workers to reduce pressure.
Interactive play and explicitly requested device/simulator debugging remain
available; the CI policy applies to automatic verification, not to playing the game.

## Gate composition

| Gate | Composition |
|---|---|
| `handoff.sh` | Locally: scoped style, fast selected script regressions, docs and cheap static slices; reports generation, compilation, package and UI work as CI-owned |
| `ci-gate.sh` | Pinned-tool ensure, generate/stamp alignment, assert against HEAD, full-tree style, module boundaries, script syntax and regression tests, API-ban policy (incl. XCTest migration), release-note validation, artwork budget |
| `ci-gate.sh --fast` | Only the ordered commands in [the cheap-slice registry](../../Scripts/config/cheap-slices.txt) |
| `ci-assets-gate.sh` | Generate assets, assert, regenerate in a stable locale, assert again |
| `test-deploy.sh` | Full CI/release test sequence; local execution requires a deliberate heavy-local diagnostic opt-in. Keep release/TestFlight evidence requirements intact |
| Main CI | Post-push on `main` (no pull-request workflow): path filter, generation/style/full script regressions, app build with smoke on the same runner, and package unit for product changes |
| Clean analysis | Explicit local `lint-analyze.sh [SwiftPath ...]` cleanup using a clean app build; unused imports fail the command; never part of CI or handoff |
| Device Release compilation | Nightly and manual CI run unsigned device Release compilation serialized behind build+unit with a 30-minute wall watchdog; failures block that run’s `CI OK`, ordinary pushes skip it. Signing/export/upload remain TestFlight responsibilities. |
| Nightly exhaustive | Scheduled or manually dispatched exhaustive UI with all registered classes on one runner; advisory, never blocks `CI OK` |
| Performance diagnostics | Manual `performance.yml` dispatch with a validated group/repetition selection; never part of routine local or push verification |

Idle nightlies skip a commit only after its previous scheduled run succeeded and
all actual exhaustive UI shards passed. Failed, cancelled, missing, or unreadable
results retry on the next schedule; advisory status cannot substitute for shard
success.

`Smoke.xctestplan` and `FullUI.xctestplan` are disjoint. Default deploy verification
runs FullUI; main CI supplies smoke coverage separately. The release workflow
requires green main CI. Use `--mode smoke` for the optional local smoke canary.

Generation in full gates is intentionally uncached: CI and an explicitly enabled
heavy handoff invoke `generate.sh` directly, including repeated generation for
idempotence. Lightweight local handoff and pre-push do not regenerate. Only the
`prepare_generated_inputs` freshness path inside build/test wrappers skips
generation, and only when content, project, and asset inputs are all unchanged.

The build job compiles app test products once, runs smoke on that runner, and
publishes products for exhaustive UI. Exhaustive UI runs every registered FullUI
class on one runner with one product transfer. It restores the exact-run product
archive through the cache service first, falls back to the retained artifact on
cache miss, and rebuilds only when transferred products cannot be validated.
Package unit jobs restore separately keyed incremental state in their per-package
DerivedData tenants, then always invoke compilation/testing so changed inputs rebuild.
They do not download the app product archive.

Manual runs queue behind current branch verification without allocating a waiting
runner. They reuse successful standard checks only for the exact commit and branch,
with actual successful build/smoke, gate, and all unit jobs plus an available product
artifact. Skipped jobs, expired products, and unreadable evidence fall back to ordinary
verification. Asset verification is reused only with its own successful job evidence;
manual device Release compilation still runs. New pushes supersede obsolete branch runs.
See [ci-reuse.py](../../Scripts/ci-reuse.py) for the proof contract. Exact shards, artifact contracts, cache inputs, and remaining advisory
job behavior belong to the checked-in workflows ([tests.yml](../../.github/workflows/tests.yml) and
related workflow files); update this guide only when the verification policy
changes.

Ordinary `build.sh` compiles only the app; it does not produce reusable test
bundles. CI keeps app incremental build state in its warm cache and transfers only
runtime products, build stamps, and versioned environment metadata in a tar archive to preserve executable permissions. Compiler-only Swift module metadata is omitted from transfers; runtime shaders and artwork remain intact.
Local reuse requires matching Xcode, SDK, architecture policy, configuration, and
test fingerprint as well as unchanged sources. The selected Xcode product version
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

## Style and boundary ownership

| Check | Owns |
|---|---|
| SwiftFormat | Mechanical Swift formatting, modifier ordering, and preferred rewrites |
| SwiftLint | API idioms, semantics, size, and unsafe operations |
| `check-ui-style.py` | Product colors, materials, and chrome routed through `TrinketDesign` |
| `check-api-bans.sh` | Repository-banned legacy observation/navigation APIs plus XCTest-outside-UITests migration |
| `check-exclusivity-footguns.sh` | Suspicious `inout` access to stored properties |
| `check-agent-invariants.sh` | BattleEngine entropy, test `Task.sleep`, persistence `try?`, undocumented concurrency escapes, SwiftLint disables without reasons |
| `check-accessibility-ids.py` | Unique `AccessibilityID` constants; UITests must query `AccessibilityID.*` |
| `check-module-boundaries.sh` | Package layering and imports |

API bans and SwiftLint suppression reasons are enforced by the scripts in the
table above (pinned SwiftFormat token export through
`Scripts/internal/swift_policy.py`); SwiftLint has no custom-rule mirrors.
Comments and string literals are not API usage; code inside string
interpolation is. A suppression requires a nonblank ` - <reason>` in its
actual line comment, including when that directive follows code. Flag and
syntax details live in each script's usage text.

`Color.primary`, `.secondary`, and `.clear` remain valid adaptive primitives.
Feature-specific product colors and visual effects go through the design system.
Use a checker-approved `UIStyleCheck: allow - reason` annotation only for a
narrow content/art exception that the semantic API cannot express; never use it
to bypass product chrome routing.

## Failures and reporting

`handoff.sh --quiet` prints one outcome per phase and retains complete child terminal
output under `RESULTS_DIR` or `.DerivedData/HandoffResults`. Failed phases include a
bounded diagnostic excerpt and the full log path. Selected-check, documentation
and cheap-slice failures also print a shell-quoted rerun preserving the supplied
flags and paths. Agent commands select quiet mode; omitting the flag retains detailed terminal
output. Quiet mode does not change selected checks or failure status.

Documentation/link failures are grouped with bounded location previews. Complete
reports are retained under `RESULTS_DIR` or `.DerivedData/DocumentationResults`;
use the printed paging/expansion commands to inspect every relevant failure.
Failure status does not depend on how many locations are printed. SwiftLint
suppresses per-file progress while retaining violations and a success summary.

When a full handoff plan is executed and Xcode is unavailable, handoff runs
available checks and reports `INCOMPLETE` with exit code 2 if selected app
compilation could not run. Its dry run lists that unavailable requirement.
Lightweight local handoff instead defers compilation to CI, including on hosts
without Xcode; its PASS proves only the available lightweight checks.

Classify a failure before changing code: task regression, pre-existing defect,
unrelated in-flight change, or tooling/environment failure. Use the failing assertion and a bounded
reproduction to establish the cause. Adopt a fix only under the root guide's
encountered-fix rules; never weaken a check, omit a changed path, or overwrite
unrelated work to obtain a pass. If blocked, report the failed command, known
cause, and remaining verification. Rerun affected checks after a fix; broaden
verification only when the failure exposes another affected owner.

Evidence-based test retirement follows [Testing.md](Testing.md#consolidation-and-retirement);
it must not conceal a defect. Run the routed handoff for changed and deleted paths
after pruning, including affected test registration. Verification requires evidence,
not accompanying test-file edits for every production change. Test additions follow
Testing.md's high-value threshold and rare medium-value exception rule; required
execution and release evidence do not automatically require new test code.

Read structured invocation reports before raw build logs. Use
`./Scripts/ci-diagnostics.sh <results-dir>` to aggregate them and follow
[CI diagnostics](../AgentContext/ci-diagnostics.md) for classification and
escalation. Process safety follows [AGENTS.md](../../AGENTS.md#protect-the-workspace).

The push gate may print an advisory change-budget report. Counts can prompt
investigation but do not require a justification for every threshold crossing.
Distinguish the task's changes from pre-existing edits against HEAD. Explain
material tradeoffs when they affect the solution. Timing logs are diagnostic data,
not a routine optimization mandate.

Commit and push safeguards follow [Release.md](Release.md#local-hooks-and-push-discipline).
Landing policy remains in [AGENTS.md](../../AGENTS.md#protect-the-workspace).
Hosted CI follows a requested push; do not require `tests / CI OK` as a GitHub
push gate on `main`.
