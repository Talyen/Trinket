# Trinket agent guide

Portrait-first iOS fantasy turn-based card combat.

## Guardrails

- These rules apply repository-wide. The nearest nested `AGENTS.md` adds path-specific instructions without relaxing root safety, boundary, or generated-output rules.
- Preserve existing work. Do not clean, revert, overwrite, stage, or include unrelated changes.
- Keep work within the requested scope. Report verification failures and skipped checks.
- Treat checked-in project configuration as the toolchain source of truth. Do not add legacy-platform compatibility or UIKit bridges when current SwiftUI provides a first-party solution.
- Never hand-edit generated code, processed assets/resources, `.DerivedData/`, `.tools/`, or the Xcode project. Edit authored inputs and use the routed generation checks.
- Work locally on `main`. Do not create or switch branches, commit, push, tag, or open a PR unless explicitly requested. For requested commit or release work, read `Scripts/README.md`.

## Task routing

Once the likely paths are known, run:

`./Scripts/agent-context.sh --paths <file...>`

Read only the nested guides, context cards, and skills it selects. Rerun it only if the task crosses into another area.

## Isolated verification

Agents must verify with an isolated tenant so peers on the same Mac do not share DerivedData or the default simulator:

`./Scripts/verify-changed.sh --isolate --paths <file...>`

That acquires a reusable agent simulator slot (`Trinket Agent N`, pool size `TRINKET_MAX_AGENT_SIMS`, default 3), DerivedData under `.DerivedData/runs/agent-N/`, and a unique `TRINKET_RUN_ID` for diagnostics. Slot sims stay Booted between runs so cold create/boot is amortized. Humans and CI may omit `--isolate` to keep the shared warm cache (`.DerivedData` + `Trinket CI`).

Rules:

- Never kill foreign `xcodebuild`, `simctl`, or Simulator processes to start your own checks.
- Generation uses a shared lock with a timeout (default 120s). On timeout, report and retry later or continue in a worktree — do not sleep-loop for minutes.
- Isolated runs fail fast when the agent simulator pool is full. UI/smoke/all modes also take a fail-fast UI concurrency slot (`TRINKET_MAX_CONCURRENT_UI`, default 2). Do not wait; use a worktree or retry after a peer finishes.
- Isolated unit/package runs may proceed in parallel once each has its own agent slot / DerivedData. Do not parallelize **shared-tenant** (non-`--isolate`) `test.sh` wrappers.
- On failure, run diagnostics against **this run’s** `RESULTS_DIR` (printed by `run-env`), not a peer’s path.

Use a worktree when another agent already dirtied overlapping paths, you need long-lived source isolation, or the UI/sim cap is saturated:

`./Scripts/agent-worktree.sh create <slug>`

Then `cd` into the sibling checkout and verify with `--isolate`.

## Verification

Before handoff, run the path-scoped checks with isolation:

`./Scripts/verify-changed.sh --isolate --paths <file...>`

Use `--dry-run` only when previewing an unfamiliar or potentially expensive route.

- For a small UI feature confined to one screen or flow, run the path-scoped plan from
  `./Scripts/verify-changed.sh --isolate --paths <file...>` (always includes style for
  Swift changes, plus package tests when a package is touched). Prefer
  `SmokeClass/testMethod` when one method directly owns the behavior. Do not run bare
  smoke, the full unit suite, `smoke-full`, or exhaustive UI tests for that iteration;
  those belong to pre-push or CI gates.
- If no existing smoke class closely covers the changed behavior, add or update one focused smoke test and run only that class. Do not use the unrelated Homestead canary as a substitute.

If verification fails, follow `Docs/AgentContext/ci-diagnostics.md` and use its structured reports before opening raw logs.

## Commit, push, and CI babysit

Agent contract (do not skip):

1. Mid-task: `./Scripts/verify-changed.sh --isolate --paths <file...>` (idempotent generate assert).
2. Before commit/push: `./Scripts/agent-push-gate.sh` (or `verify-changed.sh --isolate --push-ready --paths …`). Uses pinned `.tools` XcodeGen with `--force-xcodegen` and asserts vs HEAD; includes `--assets` only when classification says assets changed.
3. After push to `main`: `./Scripts/agent-watch-ci.sh` until green. If path filters skipped substantive jobs, it dispatches a full `workflow_dispatch` run and watches that too.

Never “fix” generated drift by hand-editing `project.pbxproj` or committing lossy asset re-encodes from CI. Regenerate with pinned tools (`./Scripts/ensure-ci-tools.sh` + `./Scripts/generate.sh --force-xcodegen`); use `FORCE_ASSET_REENCODE=1` only for intentional binary refreshes.
