# Verification and CI

## Confidence ladder

Run `./Scripts/handoff.sh --quiet` from the task checkout. It derives the complete
task scope from `main` (commits plus dirty files) and runs lightweight static checks.
Compilation, package tests, simulator suites, generation freshness and performance
qualification belong to hosted CI, including for directly changed packages and public APIs.
The ordinary completion path is implementation, static handoff, review and commit,
then protected local integration. Use judgment about the actual change to select
any additional local evidence under the visual gate below.
Use `--base <ref>` for another approved base, `--paths <files...>` for an iteration,
and `--dry-run` to preview without executing anything.

| Need | Command | Evidence |
|---|---|---|
| Ordinary task verification | `handoff.sh --quiet` | Scoped static checks; compilation and test obligations reported as deferred to CI |
| Cheap static checks only | `handoff.sh --route static --paths <files...>` | Style, scripts/docs and cheap invariants; no compilation or simulator |
| One concrete local diagnostic | Exact selector under the [single focused diagnostic limits](#single-focused-local-diagnostic) | One bounded attempt without additional approval; setup counts toward the deadline |
| Expressly requested local package diagnostic | `TRINKET_ALLOW_HEAVY_LOCAL=1 handoff.sh --package <Package...> --paths <files...>` | Selected package tests, executed serially |
| Expressly requested local app compilation | `TRINKET_ALLOW_HEAVY_LOCAL=1 handoff.sh --app-only --paths <files...>` | App and unchanged downstream consumers compile |
| Expressly requested local UI diagnostic | `TRINKET_ALLOW_HEAVY_LOCAL=1 handoff.sh --ui <Class[/method]> --paths <files...>` | The selected registered Smoke/FullUI journey |
| Inspect changed visuals | `handoff.sh --route visual --paths <files...>` in a persistent terminal | Managed build/launch/capture session; actual image and interaction review still required |
| Requested release qualification | `TRINKET_ALLOW_HEAVY_LOCAL=1 handoff.sh --route release --paths <files...>` | Full release verification without publishing |

The default `auto` route and local `static` route never enable compiled work,
even if a shell inherited `TRINKET_ALLOW_HEAVY_LOCAL=1`. Direct package edits,
shared-fixture consumers, app/UI changes and public-API consumer checks remain
visible as hosted obligations. Main CI already runs routed package tests and app
build/Smoke qualification; nightly and manual lanes own broader UI/performance work.
The preview and report list selected and deferred work; a skipped or unexecuted
check never counts as passed. Default selection does not certify visual quality.

For script changes, ordinary local handoff checks syntax and cache-path alignment
with `test-scripts.sh --syntax-only`; regression suites remain visible as hosted
obligations. `--fast` still executes tests and is not a static-only gate. Use exact
focused regressions under the diagnostic limits when local evidence is needed.

Explicit selectors run only that selected work; they do not replace static landing
checks. `--route focused` is optional and `diagnostic` remains a compatibility alias.
`--isolate` is also retained for compatibility; isolation is automatic. Ordinary
verification needs no additional user approval or manual environment flags.
Focused/release execution requires `TRINKET_ALLOW_HEAVY_LOCAL=1` locally and either
the single focused diagnostic exception below or an express user request for that
local work; selectors alone never enable the override.
Dry-run previews need no opt-in. The bounded visual route remains authorized by
the visual completion gate below.

Local `build.sh`, compiled `test.sh`, `test-package.sh`, and managed `run-simulator.sh --isolate` automatically enter the shared host admission helper before allocating resources. Hosted CI and nested commands reuse their existing ownership; human simulator play is unchanged. The helper defaults to `~/Developer/.coordination/heavy_lane.py`; `CODEX_HEAVY_LANE_HELPER` can select its existing location. Busy or missing admission exits 75 with no build or simulator setup, rather than reporting a passed check. Its default wait is 30 seconds and command deadline five minutes. Other explicit diagnostic wrappers still follow the machine admission guidance.

Before landing, follow [review and integration](Release.md#landing-and-review).
Local integration requires static checks and visual review only when the
[visual completion gate](#visual-completion-gate) applies. Local compiled evidence
is not required. Report hosted verification as pending.

## Completion states

- **Locally verified:** the selected local checks passed; read the report for its scope.
- **Locally integrated; hosted verification pending:** reviewed work landed on local main. This completes an authorized local task when no required visual evidence or other local work is missing.
- **Hosted verified:** required hosted checks actually passed for the intended revision after an authorized push.
- **Implemented, visually unverified:** required shipping-UI evidence is blocked; report the exact prerequisite and do not claim the visual task complete.

Pushes and publication remain separately authorized. Missing hosted evidence is
reported without blocking a local-only task or authorizing a push. Task reports
record local landing and pending hosted verification automatically.

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
   minimum supported runtime as well as the newest one, including both branches
   of any new availability checks and intermediate runtimes where those branches
   differ. Use the [minimum-OS lane](PlayerCoverage.md#ci-and-profiles) for its
   explicit compatibility scope. Confirm the leased simulator's runtime: a
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

The project-output registry includes the workspace descriptor, shared schemes,
Info.plist, and entitlements alongside the project file. Staged validation checks
those outputs and generated UI-plan selections, including newly generated files
omitted from the index.
The committed-output and idempotence gates also cover the shared schemes used by
build runners that skip generation.

## Local simulator budget

### Choosing UI verification

Use automatic handoff for ordinary work. A changed interaction or accessibility
identifier also requires its relevant hosted journey evidence; handoff selects
Smoke obligations automatically. Use the [Testing rubric](Testing.md#ui-keep-drop-rubric)
when no existing journey owns the outcome. For a bounded local reproduction, use
`--ui Class[/method]`; do not run the complete hosted portfolio on the laptop.

### Visual completion gate

Require local rendered review for changes to player-facing layout, styling,
artwork, motion, or UI interaction, and for a clear text-fit or readability risk.

Content, balance, gameplay-rule and copy changes within existing UI follow the
ordinary static completion path unless they create one of those presentation or
interaction risks. Text changes still complete localization in the same task;
compilation and combat tests remain CI-owned. An optional local diagnostic timing
out does not by itself block integration or make such a task visually incomplete.
Agents determine whether the gate applies from the actual change; no separate
approval or checklist is needed.

When the gate applies:

1. Render the changed result using the shipping UI and real game content on a
   managed simulator or selected device. Save evidence tied to the build/revision,
   screen, device size, and relevant state. Inspect the actual image; a capture
   command succeeding, a loading screen, source review, or a generated mockup is
   not proof of the implemented result.
2. Review it at normal presentation size against the request and visual references.
   Identify concrete issues in composition, artwork crop, hierarchy, copy necessity,
   legibility, and interaction. Compare before/after in matching states when
   claiming improvement. Exercise changed interactions; use a recording or live
   inspection for motion.
3. Fix visible issues, render the revised result, and review again. Continue until
   the requested result meets the brief. If the first render needs no correction,
   record what was inspected and why it meets the brief; do not invent edits to
   satisfy an iteration count.
4. Link final evidence and summarize the review and refinements in the handoff.
   Save deliverables in `.DerivedData/Deliverables/`; integration preserves them
   outside the task checkout before cleanup. Use `agent-worktree.mjs evidence
   <paths...>` to preserve other task-local files immediately. If a
   rendering prerequisite is unavailable, report **implemented, visually unverified**
   with the exact blocker; do not call the visual task done or polished.

Bounded local build/launch/capture and iteration for this gate are authorized
without separate approval. Use the [simulator skill](../../.agents/skills/ios-simulator/SKILL.md)
or [device skill](../../.agents/skills/ios-device/SKILL.md), preserve lease isolation,
and state the scope before running. This exception does not authorize broad UI,
performance, or hosted suites locally. Existing evidence is reusable only if it
shows the final changed result and relevant states; pre-change captures do not
satisfy the gate. Guidance-only edits use scenario review, not a synthetic UI build.

### Execution limits

Do not run local compilation, package tests, simulator test journeys, full script
qualification or performance measurements merely to complete an ordinary task.
A task request, a failing CI check, or an explicit selector alone is not permission
to move broad qualification onto this Mac. Use lightweight handoff and report hosted
checks as pending until an authorized push runs them. Do not push just to obtain CI.

For an authorized single focused diagnostic or expressly requested local diagnostic/release run, set
`TRINKET_ALLOW_HEAVY_LOCAL=1` with the selected command. Local package checks then
execute serially; UI workers remain serialized and app builds use two workers.
The visual completion gate and interactive play retain their bounded build/launch
exceptions. Bare FullUI additionally requires
`TRINKET_ALLOW_FULL_UI=1`. Never forge `CI`/`GITHUB_ACTIONS` or use flags to bypass
resource policy. Stubbed script fixtures may simulate these environments without
starting real builds or simulators. Local script regressions use at most two
workers (`TRINKET_SCRIPT_TEST_JOBS=1` serializes them on a busy machine).

### Single focused local diagnostic

An agent may run one local compiled diagnostic without asking for approval when
it answers a concrete unresolved question in the current task. Select one exact
test method or one small, directly relevant test suite/file; an entire package,
unfiltered UI plan, performance sweep or release suite does not qualify.

Wrap the outermost command with the shared host admission helper using
`--wait 30 --timeout 30`. The 30-second execution budget includes generation,
compilation, simulator setup and the test itself. Use one worker and the existing
isolated checkout and managed simulator lease. Set `TRINKET_ALLOW_HEAVY_LOCAL=1`
only on that command; the flag does not grant broader authorization. For example:

```sh
python3 /Users/ryanmcintire/Developer/.coordination/heavy_lane.py \
  --owner "$CODEX_THREAD_ID" --wait 30 --timeout 30 -- \
  env TRINKET_ALLOW_HEAVY_LOCAL=1 TRINKET_ISOLATE=1 \
  TRINKET_PACKAGE_TEST_JOBS=1 TRINKET_SERIAL_TESTS=1 \
  ./Scripts/test-package.sh --only-suite LabyrinthVictoryCompletionTests TrinketAppState
```

A busy lane or deadline ends the attempt. Preserve its logs, report what actually
ran, and continue source work or hosted verification. Do not automatically retry,
widen the selector, increase the deadline, or split a larger run into repeated
diagnostics. Another local compiled attempt or a longer/broader run requires an
express user request. This exception supplies diagnostic evidence only; it does
not replace final static handoff, hosted qualification or required visual review.

### Local play

`trinket-run` and `run-simulator.sh` still build and launch for interactive play.
Manage only leased simulators or an explicitly selected physical device, and never
terminate another chat's Xcode/Simulator processes. Simulator isolation and recovery
are owned by [SimulatorOperations](SimulatorOperations.md).

## Native pure-logic qualification

Native activation requires exact-build qualification and complete executed-scope
proof. See [hosted qualification](VerificationInternals.md#native-pure-logic-qualification)
when changing that machinery.

## Execution deadlines

Use the existing bounded runner deadlines and diagnostic reserves. See
[execution deadlines](VerificationInternals.md#execution-deadlines) for CI failures.

## Gate composition

Default handoff and locked integration run lightweight static checks. Hosted
CI owns compilation and test qualification. [Gate composition and cache contracts](VerificationInternals.md#gate-composition)
are implementation references, not an everyday reading requirement.

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

The shell policy commands delegate to `check-swift-policy.py`. Their rule owners
share fail-closed search, source context, and reporting in `internal/policy_scan.py`;
the UI style and cache-path checks reuse the same search/report boundary.

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

Handoff writes a compact report under `.DerivedData/Deliverables/Verification/`
with commit/dirty state, scoped input hashes, commands, outcomes and deferred work.
Integration records the main base, full task scope and local completion state,
and preserves deliverables outside the checkout. Explicit compiled reports retain
whole-source and toolchain fingerprints as provenance; integration does not demand
or trigger local compilation. No manual verification transcript is required.
Previews establish no execution evidence. Visual artifacts still need capture and review.

`--quiet` prints phase outcomes and bounded failures. Successful raw logs are
removed; failed logs expire after 24 hours unless deliberately kept. Follow the
printed full-log or documentation-report paths to inspect all relevant failures.
Missing Xcode makes selected compilation incomplete, with exit code 2; static-only
checks can pass without Xcode and prove only their static scope.

Classify failures using the assertion and a bounded reproduction: task regression,
pre-existing defect, unrelated work, or environment/tooling failure. Fix confirmed
in-scope defects; never weaken checks, omit task paths, or overwrite unrelated work
to obtain a pass. Report the command, known cause and remaining verification when
blocked. Rerun affected checks after a fix; broaden only when new evidence warrants it.

Test additions/retirement follow [Testing](Testing.md#consolidation-and-retirement).
Read structured invocation reports before raw build logs; use
[CI diagnostics](../AgentContext/ci-diagnostics.md) for hosted failures. Commit/push
safeguards follow [Release](Release.md#local-hooks-and-push-discipline); hosted CI
runs after an authorized push, not as a prerequisite for that push.
