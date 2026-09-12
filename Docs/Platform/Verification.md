# Verification and CI

This guide owns when to choose a verification route, gate composition, test
tiers, and style ownership. Exact commands and flags live in
[verification commands](../../Scripts/Reference.md#verification) and each script's usage/option parsing.
Test authoring conventions live in [Testing.md](Testing.md). Isolation and IDE
setup: [SimulatorOperations.md](SimulatorOperations.md).

## Confidence ladder

Choose the cheapest route that answers the question at hand. Gate composition
is listed below; test authoring and tier ownership follow [Testing.md](Testing.md).

| Task | Route | Use |
|---|---|---|
| Package behavior | `test-package.sh <Package>` | Focused iteration in the owning package |
| All package behavior | `test.sh unit` | All package schemes; no app-level unit target |
| App compilation | `test.sh unit --app-only` | Compile coverage for app-level Swift changes |
| Task handoff | `handoff.sh --isolate --paths <files...>` | Required agent gate; add `--smoke` for changed interaction wiring |
| Focused interaction | `test.sh smoke <Class>` / `test.sh ui <Class>` | Existing journey, within the local limits below |
| Gate-only check | `ci-gate.sh` / `ci-gate.sh --fast` | Full gate or cheap slices; neither runs unit/UI tests |
| Local canary | `test-deploy.sh --mode smoke` | Optional human confidence run |
| Release confidence | `release.sh` / `test-deploy.sh` | Pre-release verification; sanctioned local full-UI run |
| Performance investigation | `performance.sh` | Ad hoc measurement under the performance playbook |

Path-scoped commands normalize in-repository absolute paths to repository-relative
files and reject directories or paths outside the repository.

Run `./Scripts/agent-context.sh --agent --paths <files...>` after touched paths
are known. Use `--working-tree` only for an intentional whole-tree scope. The
briefing prints the required/optional read contract and applicable handoff
route; rerun it when requested work or an encountered fix crosses into another
owner. The final path list is the union of requested work and every explicitly
adopted fix, not the task's initial path list.

Markdown routes to documentation checks even beneath script or manifest roots.
For executable script changes, handoff passes the same path scope to the script
runner. Registered leaf families run their owning and consumer regressions;
documentation checks and their direct integration tests share a focused suite;
shared infrastructure, unknown scripts and unscoped CI run the full suite. Syntax,
build-input alignment and the handoff's cheap slices remain full-tree. Family
membership lives in `Scripts/script_test_selection.py`; update it when a leaf
gains a consumer. Do not narrow shared helpers from filename similarity alone.

## Generated project consistency

`./Scripts/generate.sh` runs XcodeGen through the pinned wrapper with a fresh
cache location on every invocation. `--force-xcodegen` remains an explicit name
for that default; `--skip-xcodegen` still selects content/asset generation only.
When changed paths select generation, handoff regenerates, then forces a second
generation to check idempotence.
Changes to the spec, tool pins, or wrapper route project verification; ordinary
code edits in synchronized source folders do not add project generation.
Content, asset, and project generation inputs live in `Scripts/build-inputs.env`.
Local freshness records file membership, sizes, and modification/change times
after successful generation, so unchanged uncommitted inputs can be reused and
edits or deletions invalidate them. These inputs also drive CI filtering; build orchestration changes exercise the build jobs.
The ability inventory hashes its Swift dependencies; consistency regeneration
bypasses its reuse stamp to verify the actual output.

With hooks enabled, pre-commit checks either staged project-generation inputs or
staged `Trinket.xcodeproj/project.pbxproj`. It exports an index snapshot and
compares its regenerated project with the staged project. Partially staged
project inputs are supported; partially staged tool or hook changes are rejected
before tool installation because tooling runs from the primary checkout. The
check preserves the index and working files, including unrelated edits.

When the staged project is stale, edit the authored inputs, run
`./Scripts/generate.sh`, review the project diff, and stage the canonical output
with its inputs. Do not hand-edit the project. Pre-push and CI retain their
forced generation and comparison against committed output.

## Local simulator budget

### Choosing UI verification

Ordinary `handoff.sh --isolate --paths <files...>` runs the selected source,
package, compilation, and documentation checks. It does not run UI smoke unless
`--smoke` is supplied; a green ordinary handoff is not UI interaction evidence.

For changed interaction wiring or accessibility identifiers, use
`handoff.sh --isolate --smoke --paths <files...>` and complete the selected smoke
checks. `agent-context.sh --agent --smoke --paths <files...>` previews that route.
If no smoke owner is inferred, apply the [UI keep/drop rubric](Testing.md)
to select an existing focused journey or justify a coverage change; report any
remaining interaction gap rather than substituting the full suite. A visual-only
change needs relevant visual inspection; it does not automatically require a new
UI test. Test additions and retirement remain owned by [Testing.md](Testing.md).

Performance measurement belongs to performance investigations, not routine
Battle or UI handoff. Use the [performance playbook](PerformanceInvestigationPlaybook.md)
when making or validating a performance claim.

### Execution limits

Watch hosted suites with `agent-watch-ci.sh` instead of pre-running them locally.
Their gate roles are listed below. Locally:

- Run the package/unit checks selected by the changed paths. Documentation-only work does not require unit tests unless its route selects them.
- During interaction iteration, use the routed targeted smoke class (`test.sh smoke <Class>`).
- Debug at most one exhaustive target (`test.sh ui <Class>`) when touching its feature area.
- Bare full-suite UI is refused locally unless `TRINKET_ALLOW_FULL_UI=1`; routine development never sets it.
- The full local UI run belongs to pre-release deploy verification (`release.sh` / `test-deploy.sh`).

After a green isolated rebuild, `--no-build` is appropriate for mid-task smoke
reruns in the same slot. Routine handoff is headless by default. Exact flags
(`--smoke`, `--mirror`, `--dry-run`, `--final`) live in
[verification commands](../../Scripts/Reference.md#verification) and each script's usage text.

## Gate composition

| Gate | Composition |
|---|---|
| `handoff.sh` | Path-selected generation, style, package, app compilation, documentation, and idempotence checks, plus cheap slices; targeted smoke only with `--smoke` |
| `ci-gate.sh` | Generate/assert against HEAD, full-tree style, module boundaries, script syntax and regression tests, Swift Testing policy, release-note validation, artwork budget |
| `ci-gate.sh --fast` | Only the ordered commands in [the cheap-slice registry](../../Scripts/config/cheap-slices.txt) |
| `ci-assets-gate.sh` | Generate assets, assert, regenerate in a stable locale, assert again |
| `test-deploy.sh` | Release-time: `ci-gate.sh`, unit, then additional UI journeys (FullUI), or the optional smoke canary |
| Main CI | Post-push on `main` (no pull-request workflow): path filter, generation/style, app build, package unit, and smoke for product changes |
| Clean analysis | Explicit local `lint-analyze.sh [SwiftPath ...]` cleanup using a clean app build; unused imports fail the command; never part of CI or handoff |
| Nightly exhaustive | Scheduled or manually dispatched exhaustive UI; advisory, never blocks `CI OK` |

`Smoke.xctestplan` and `FullUI.xctestplan` are disjoint. Default deploy verification
runs FullUI; main CI supplies smoke coverage separately. The release workflow
requires green main CI. Use `--mode smoke` for the optional local smoke canary.

The shared build job produces app test products for smoke and exhaustive UI
fan-out, while package unit tests compile their own schemes in parallel. Exact
shards, artifact contracts, cache inputs, and remaining advisory job behavior belong to
the checked-in workflows ([tests.yml](../../.github/workflows/tests.yml) and
related workflow files); update this guide only when the verification policy
changes.

Ordinary `build.sh` compiles only the app; it does not produce reusable test
bundles. CI keeps incremental build state in its warm cache and transfers only
products and build stamps in a tar archive to preserve executable permissions.
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
| SwiftFormat | Mechanical Swift formatting and preferred rewrites |
| SwiftLint | API idioms, semantics, size, and unsafe operations |
| `check-ui-style.py` | Product colors, materials, and chrome routed through `TrinketDesign` |
| `check-api-bans.sh` | Repository-banned legacy observation/navigation APIs (mirrored from SwiftLint for portable builds) plus XCTest-outside-UITests migration |
| `check-exclusivity-footguns.sh` | Suspicious `inout` access to stored properties |
| `check-agent-invariants.sh` | BattleEngine entropy, test `Task.sleep`, persistence `try?`, undocumented concurrency escapes, SwiftLint disables without reasons |
| `check-accessibility-ids.py` | Unique `AccessibilityID` constants; UITests must query `AccessibilityID.*` |
| `check-comment-ban.sh` | Banned `//` in Swift authored sources (allowlist: `swift-tools-version` / `swiftlint:disable` / `swiftformat:disable` / `Generated` headers; transitional `*Check: allow` / `Concurrency-Safety:`) |
| `check-module-boundaries.sh` | Package layering and imports |

`Color.primary`, `.secondary`, and `.clear` remain valid adaptive primitives.
Feature-specific product colors and visual effects go through the design system.
Use a checker-approved `UIStyleCheck: allow - reason` annotation only for a
narrow content/art exception that the semantic API cannot express; never use it
to bypass product chrome routing.

## Failures and reporting

When Xcode is unavailable, handoff runs available checks and reports
`INCOMPLETE` with exit code 2 if the selected app compilation could not run.
Its dry run lists that unavailable requirement; it cannot report PASS.

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
not accompanying test-file edits for every production change.

Read structured invocation reports before raw build logs. Use
`./Scripts/ci-diagnostics.sh <results-dir>` to aggregate them and follow
[CI diagnostics](../AgentContext/ci-diagnostics.md) for classification and
escalation. Never kill foreign Xcode or Simulator processes.

The push gate may print an advisory change-budget report. Warnings do not fail
the task, but unusual production/test surface growth needs a necessity statement
and the simpler alternative that was rejected. Timing logs are diagnostic data,
not a routine optimization mandate.

Commit and push safeguards follow [Release.md](Release.md#local-hooks-and-push-discipline).
Landing policy remains in [AGENTS.md](../../AGENTS.md#protect-the-workspace).
Hosted CI follows a requested push; do not require `tests / CI OK` as a GitHub
push gate on `main`.
