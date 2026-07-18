# CI and project-generation context

Use for XcodeGen, build/test commands, CI workflows, simulator problems, or release tooling.

The root workflow owns task-scoped routing: start with
`./Scripts/agent-context.sh --paths <file...>` for a human briefing (`--json` is
machine-readable and `--agent` is the concise handoff form), then preview the
selected checks with `./Scripts/verify-changed.sh --dry-run --isolate --paths <same files>` and
run them by omitting `--dry-run`. Agents **always** pass `--isolate`. Without `--paths`,
both commands inspect the entire working tree; use that mode only when the tree
represents one task.

This card adds the CI/project-generation exceptions:

- `verify-changed.sh --isolate` calls `Scripts/run-env.sh` once so the whole plan
  shares one agent simulator slot (`Trinket Agent N`), DerivedData under
  `.DerivedData/runs/agent-N/`, `TMPDIR`, and a unique `TRINKET_RUN_ID` for
  diagnostics. The slot pool size is `TRINKET_MAX_AGENT_SIMS` (default 3); slot
  sims stay Booted for reuse. Omit `--isolate` only for humans/CI that want the
  shared warm cache (`.DerivedData` + `Trinket CI`).
- `verify-changed.sh` runs required generation once, then an **idempotent**
  generated-output check (`assert-generated-output.sh --idempotent`): regenerate
  must not change tracked outputs further. That answers “does this working tree
  match the manifests?” It does **not** require generated files to match HEAD —
  commit completeness is `./Scripts/agent-push-gate.sh`, pre-push, `ci-gate.sh`,
  and CI (`assert-generated-output.sh` without `--idempotent` after force generate).
- `--push-ready` on `verify-changed.sh` switches to commit-completeness (pinned
  tools + `generate.sh --force-xcodegen` + assert vs HEAD, conditional `--assets`)
  plus the normal style/package/smoke plan. Prefer `./Scripts/agent-push-gate.sh`
  when you only need the generate/assert gate.
- After push, agents must run `./Scripts/agent-watch-ci.sh`. Path-filtered green
  runs (only Path filter executed) auto-dispatch a full `Trinket CI`
  `workflow_dispatch` and watch until green.
- `generate.sh` prefers `.tools/xcodegen`. `--force-xcodegen` (or
  `TRINKET_FORCE_XCODEGEN=1`) ignores the XcodeGen cache so stale “project has not
  changed” cannot hide `project.pbxproj` drift. Agent push gate sets
  `TRINKET_REQUIRE_PINNED_TOOLS=1`. Asset prepare scripts skip re-encode when
  outputs are up to date; set `FORCE_ASSET_REENCODE=1` only for intentional
  binary refreshes.
- `verify-changed.sh` then sets `SKIP_GENERATE=1` for app
  wrapper tests so a single verification run does not regenerate the project repeatedly.
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
  package tests when packages are touched; focused smoke when UI changes). Bare `smoke`
  is the pre-push Homestead canary; full unit, `smoke-full`, and exhaustive UI suites
  remain pre-push or CI checks.
- Use `--no-build` only after a matching successful build in the **same** DerivedData
  tenant; the wrappers reject stale inputs. Without Xcode 26/simulator, run the applicable
  generation, generated-output, boundary, style, and CI-gate checks and report skipped
  build/test work.
- CI (`pr.yml` / `ci.yml`) builds once, prunes DerivedData with
  `Scripts/prune-derived-data-cache.sh`, saves a run-scoped cache, and fans out unit /
  smoke / exhaustive UI via `.github/actions/test-job` (`--no-build`, rebuild-on-miss).
  Smoke/UI cache-miss rebuilds use `build-for-testing.sh --app-only`.
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
a simulator.

## Swift Testing compile checklist

When adding `@Test(arguments:)` cases (see `Docs/Platform/Testing.md`):

1. `private` argument types ⇒ `private` test function.
2. Argument / tuple element types ⇒ `Sendable` (typically also `Hashable`).
