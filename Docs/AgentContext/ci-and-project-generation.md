# CI and project-generation context

Use for XcodeGen, build/test commands, CI workflows, simulator problems, or release tooling.

The root workflow owns task-scoped routing: start with
`./Scripts/agent-context.sh --agent --paths <file...>` for a concise briefing
(`--json` is machine-readable), optionally preview an unfamiliar or potentially
expensive route with `./Scripts/verify-changed.sh --dry-run --isolate --paths <same files>`,
then run it by omitting `--dry-run`. A preview does not count as verification.
Agents **always** pass `--isolate`. Without `--paths`,
both commands inspect the entire working tree; use that mode only when the tree
represents one task.

This card adds the CI/project-generation exceptions:

- `verify-changed.sh --isolate` calls `Scripts/run-env.sh` once so the whole plan
  shares one agent simulator slot (`Trinket Agent N`), DerivedData under
  `.DerivedData/runs/agent-N/`, `TMPDIR`, and a unique `TRINKET_RUN_ID` for
  diagnostics. The slot pool size is `TRINKET_MAX_AGENT_SIMS` (default 3); test
  wrappers leave one managed simulator booted and shut down excess managed
  agent simulators after the run. Shared `Trinket CI` and agent simulators held
  by another active run are preserved. Set
  `TRINKET_CLEANUP_EXCESS_SIMULATORS=0` to keep the warm pool. Omit `--isolate`
  only for humans/CI that want the shared warm cache (`.DerivedData` + `Trinket CI`).
- `verify-changed.sh` runs required generation once, then an **idempotent**
  generated-output check (`assert-generated-output.sh --idempotent`): regenerate
  must not change tracked outputs further. That answers “does this working tree
  match the manifests?” It does **not** require generated files to match HEAD —
  use it before commit, then review and stage only the task's authored and generated
  files. After commit, commit completeness is `./Scripts/agent-push-gate.sh`,
  pre-push, `ci-gate.sh`, and CI (`assert-generated-output.sh` without
  `--idempotent` after force generate). If the post-commit gate regenerates files,
  review them, amend the commit, and rerun it.
- Without explicit `--paths`, `agent-push-gate.sh` classifies working-tree paths;
  when the tree is clean after a commit, it classifies local commits not present on
  a remote, falling back to the latest commit. This preserves conditional asset
  generation in the documented post-commit workflow.
- `--push-ready` on `verify-changed.sh` switches to commit-completeness (pinned
  tools + `generate.sh --force-xcodegen` + assert vs HEAD, conditional `--assets`)
  plus the normal style/package/smoke/compile plan. Prefer `./Scripts/agent-push-gate.sh`
  when you only need the post-commit generate/assert gate — it does **not** run
  style or compile. Do not use `--push-ready` as a pre-commit consistency check;
  intentional uncommitted generated output differs from HEAD by definition.
- After push, agents must run `./Scripts/agent-watch-ci.sh` (quiet JSON polls by
  default — do not stream `gh run watch` into the agent context; use `--verbose`
  only for humans). On failure, read failed job names, printed check-run
  annotations, and the short log excerpt. Path-filtered green runs auto-dispatch a
  full `Trinket CI` `workflow_dispatch` and watch until green. Simulator/XCUITest
  launch flakes get one automatic `gh run rerun --failed` (disable with
  `--no-infra-rerun`). Classification is shared via `./Scripts/ci-infra-rerun.sh`
  and also covers Nightly Integration / App performance job names. Nightly gets a
  separate one-shot infra rerun from `.github/workflows/nightly-infra-rerun.yml`
  when attempt 1 fails on infrastructure only.
- `generate.sh` exports `LC_ALL=C` / `LANG=C` so asset hash TSV headers stay
  stable on CI locales. It also pins `DEVELOPER_DIR` + `SDKROOT` to Xcode's
  macOS SDK (rejects Command Line Tools SDK) before `content_codegen` / SPM
  `swift run`, so newer macOS/CLT betas cannot mismatch Xcode's `swiftc`. Asset
  prepare scripts also preserve the two header lines
  and sort data rows with `LC_ALL=C sort` — keep that pattern for any new
  `*SourceHashes.generated.tsv` writer. `generate.sh` prefers `.tools/xcodegen`.
  `--force-xcodegen` (or `TRINKET_FORCE_XCODEGEN=1`) ignores the XcodeGen cache so
  stale “project has not changed” cannot hide `project.pbxproj` drift. Agent push
  gate sets `TRINKET_REQUIRE_PINNED_TOOLS=1`. Art prepare invalidates on source
  content hash (not mtime); other asset prepare scripts still use mtime. Set
  `FORCE_ASSET_REENCODE=1` only for intentional binary refreshes.
- `verify-changed.sh` then sets `SKIP_GENERATE=1` for app
  wrapper tests so a single verification run does not regenerate the project repeatedly.
- Completed task-scoped and push-gate runs print an advisory `change-budget.sh`
  report. It excludes generated output and never fails solely for size; warnings
  require a necessity explanation. Use `verify-changed.sh --quiet` for PASS/FAIL
  lines and bounded failure excerpts rather than streaming successful command logs.
- Generation uses a **shared** lock at `.DerivedData/.generate.lock` with
  `TRINKET_GENERATE_LOCK_TIMEOUT_SECONDS` (default 120). On timeout, fail fast — do not
  kill the holder. XcodeGen cache stays at `.DerivedData/XcodeGen.cache`.
- Shared-tenant (non-isolated) app `test.sh` wrappers must not run in parallel: they
  share the app DerivedData `build.db`. Package schemes use per-package tenants under
  `$DERIVED_DATA_PATH/packages/<name>/` so package builds and package tests can run
  in parallel. Isolated unit/package runs may proceed in parallel once each has an
  agent slot. UI/smoke modes also take a fail-fast concurrency slot
  (`TRINKET_MAX_CONCURRENT_UI`, default 2). Agent sim slots and UI slots are both
  fail-fast when full.
- Use a filtered command for intentionally narrow work; an affected player flow needs
  only the path-scoped plan from `verify-changed.sh` (style always when Swift changes;
  package tests when packages are touched; focused smoke when a SmokeClass resolves;
  compile-only `build.sh` when feature/shared/model Swift has no unit or smoke owner).
  Bare `smoke` is optional local Homestead confidence. Full unit, `smoke-full`, and
  exhaustive UI are CI or explicit full-local flows, not pre-push hook requirements.
- Use `--no-build` only after a matching successful build in the **same** DerivedData
  tenant; the wrappers reject stale inputs. Without Xcode 26/simulator, run the applicable
  generation, generated-output, boundary, style, and CI-gate checks and report skipped
  build/test/compile work. Linux portable SwiftLint also skips SourceKit `custom_rules`
  and can under-report idiomatic findings vs macOS CI — treat local style PASS as
  provisional for CI parity.
- CI (`pr.yml` / `ci.yml`, via the shared `tests.yml`) builds once, prunes DerivedData with
  `Scripts/prune-derived-data-cache.sh`, uploads a run-scoped artifact for test fan-out, and
  saves a two-tier warm cache (`build-<nonsource>-<full>`) only on exact miss — prefix
  restore-keys reuse same toolchain/assets for incremental source rebuilds. Unit / smoke /
  exhaustive UI restore that artifact via `.github/actions/test-job` (`--no-build`,
  rebuild-on-miss). Smoke/UI artifact-miss rebuilds use `build-for-testing.sh --app-only`.
- Parallel source trees: `./Scripts/agent-worktree.sh create <slug>` then verify with
  `--isolate` inside the sibling checkout.

When a test or CI invocation fails, load
[`ci-diagnostics.md`](ci-diagnostics.md) before inspecting raw logs. Read
`Scripts/README.md` for gate composition and `Docs/Platform/Testing.md` for test
ownership.

## Style gate (fail closed)

`./Scripts/test.sh style` must fail when SwiftFormat lint, SwiftLint `--strict`,
UI style, platform API bans, or exclusivity footguns fail. Do not treat a non-zero
subgate as success.

Path-scoped `verify-changed.sh` always includes style when Swift sources change, and
always includes `test-package.sh` for each touched package — those failures never need
a simulator. Feature/Shared/Models paths with no resolved smoke owner also schedule
compile-only `./Scripts/build.sh` when `xcodebuild` is present (generic simulator
destination, no boot) so Swift 6 concurrency and Testing-macro errors are not
style-only false greens. That tier does **not** expand QuickSmoke.

**Linux / portable SwiftLint:** SourceKit `custom_rules` are skipped, and some
idiomatic findings may not match macOS CI. Style PASS on Linux is not a substitute
for CI macOS style. On GitHub Actions, `lint.sh` emits both `xcode` (log-visible)
and `github-actions-logging` (Checks annotations) reporters so `agent-watch-ci`
excerpts and annotations both show rule/file/line.

## Swift Testing compile checklist

When adding `@Test(arguments:)` cases (see `Docs/Platform/Testing.md`):

1. `private` argument types ⇒ `private` test function.
2. Argument / tuple element types ⇒ `Sendable` (typically also `Hashable`).
3. Keep `#require` arguments simple; compute `first(where:)` / key-path lookups into a local before `#require`.
