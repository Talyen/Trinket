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
- `verify-changed.sh` runs required generation once, then sets `SKIP_GENERATE=1` for app
  wrapper tests so a single verification run does not regenerate the project repeatedly.
- Generation uses a **shared** lock at `.DerivedData/.generate.lock` with
  `TRINKET_GENERATE_LOCK_TIMEOUT_SECONDS` (default 120). On timeout, fail fast — do not
  kill the holder. XcodeGen cache stays at `.DerivedData/XcodeGen.cache`.
- Shared-tenant (non-isolated) `test.sh` wrappers must not run in parallel: they share
  DerivedData `build.db`. Isolated unit/package runs may proceed in parallel once each
  has an agent slot. UI/smoke modes also take a fail-fast concurrency slot
  (`TRINKET_MAX_CONCURRENT_UI`, default 2). Agent sim slots and UI slots are both
  fail-fast when full.
- Use a filtered command for intentionally narrow work; an affected player flow needs
  only `TRINKET_ISOLATE=1 ./Scripts/test.sh smoke <SmokeClass>` during feature iteration.
  Bare `smoke` is the pre-push Homestead canary; global style, full unit, `smoke-full`,
  and exhaustive UI suites remain pre-push or CI checks.
- Use `--no-build` only after a matching successful build in the **same** DerivedData
  tenant; the wrappers reject stale inputs. Without Xcode 26/simulator, run the applicable
  generation, generated-output, boundary, style, and CI-gate checks and report skipped
  build/test work.
- Parallel source trees: `./Scripts/agent-worktree.sh create <slug>` then verify with
  `--isolate` inside the sibling checkout.

When a test or CI invocation fails, load
[`ci-diagnostics.md`](ci-diagnostics.md) before inspecting raw logs. Read
`Scripts/README.md` for gate composition and `Docs/Platform/Testing.md` for test
ownership.
