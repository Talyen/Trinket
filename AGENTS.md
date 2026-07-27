# Trinket agent guide

Portrait-first iOS fantasy turn-based card combat.

## Guardrails

- These rules apply repository-wide. A nested `AGENTS.md` may add or tighten path-specific rules, but it may not relax this root Guardrails section.
- Preserve existing work. Do not clean, revert, or overwrite unrelated changes, and never stage or commit them.
- Keep work within the requested scope. Report verification failures and skipped checks.
- Treat checked-in project configuration as the toolchain source of truth. Do not add legacy-platform compatibility or UIKit bridges when current SwiftUI provides a first-party solution.
- Never hand-edit generated code, processed assets/resources, `.DerivedData/`, `.tools/`, or the Xcode project. Edit authored inputs and use the routed generation checks.
- Stay on the current branch/worktree, normally `main`. Do not create or switch branches, commit, push, tag, or open a PR unless explicitly requested. For requested commit or release work, read `Scripts/README.md`.

## Change discipline

- Deliver the smallest change that fully satisfies the request. Do not add speculative extension points, compatibility paths, defensive layers for impossible states, or adjacent cleanup.
- Prefer smaller surface area: delete → reuse → simplify locally → parameterize a confirmed duplicate → add an abstraction.
- Extend the module that already owns the behavior before adding a file, type, protocol, manager, helper, wrapper, or configuration object. A generic abstraction needs at least three current uses or an enforced architectural boundary; predicted future reuse is insufficient.
- Refactors remove the replaced path. Do not leave forwarding wrappers, parallel implementations, or duplicate tests unless compatibility explicitly requires them.
- Treat authored production and test surface as budgets. Unusual growth is advisory, not a license to compress code: report the necessity and the simpler alternative rejected when `./Scripts/change-budget.sh` warns.

## Task routing

Touched areas must respect their nested guides and AgentContext cards. `./Scripts/agent-context.sh --agent --paths <file...>` is the catalog for discovering path-specific guidance, skills, and verification plans — not a prerequisite ritual before thinking. Rerun it when the task crosses into another area.

## Test and verification discipline

- Verification does not imply authoring a test. Add or expand coverage only for a distinct consequential behavior or invariant that is not already covered, would fail before the change (except genuinely new behavior), and belongs in the cheapest suitable tier.
- Extend the closest existing semantic owner before adding a declaration, file, or class. Do not test plumbing, stored-property round trips, display copy, layout constants, framework behavior, or trivial delegation.
- UI tests are exceptional: keep one owner for a shipping shell/entry, state-changing journey, or safety invariant that lower tiers cannot prove. Never duplicate it across smoke and exhaustive UI. See `Docs/Platform/Testing.md`.
- Before handoff, changed paths must pass path-scoped verification with `--isolate`. `./Scripts/verify-changed.sh --isolate --paths <file...>` is the canonical gate. Never kill foreign Xcode or Simulator processes; concurrency, worktree, lock, and diagnostics details live in `Docs/AgentContext/ci-and-project-generation.md` and `Docs/AgentContext/ci-diagnostics.md`.
- At handoff, summarize the behavior changed, verification status (what ran, pass/fail, skips), and any change-budget justification.

## Commit, push, and CI babysit

- Commits include only task-related authored and generated files and must pass repository hooks. Path-scoped verification should be green before commit.
- Push only when explicitly requested. Generation completeness against HEAD (`./Scripts/agent-push-gate.sh`) must be green before push; if generation changes files, review them, include them, and ensure the gate is clean. Exact commands: `Scripts/README.md`.
- After an explicitly requested push, watch CI for the pushed HEAD until green (`./Scripts/agent-watch-ci.sh`). On failure, read failed job names, check annotations, and the short log excerpt.
