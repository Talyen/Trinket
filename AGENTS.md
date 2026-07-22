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

- Implement the smallest complete change. Do not add speculative extension points, compatibility paths, defensive layers for impossible states, or adjacent cleanup.
- Prefer, in order: delete → reuse → simplify locally → parameterize a confirmed duplicate → add an abstraction.
- Modify the existing owner before adding a file, type, protocol, manager, helper, wrapper, or configuration object. A generic abstraction needs at least three current uses or an enforced architectural boundary; predicted future reuse is insufficient.
- Refactors remove the replaced path. Do not leave forwarding wrappers, parallel implementations, or duplicate tests unless compatibility explicitly requires them.
- Treat authored production and test surface as budgets. Unusual growth is advisory, not a license to compress code: report the necessity and the simpler alternative rejected when `./Scripts/change-budget.sh` warns.

## Task routing

Once the likely paths are known, run:

`./Scripts/agent-context.sh --agent --paths <file...>`

For repository guidance, read only the nested guides, context cards, and skills it selects, plus resources they directly require. Rerun it only if the task crosses into another area.

## Test and verification discipline

- Verification does not imply authoring a test. Add or expand coverage only for a distinct consequential behavior or invariant that is not already covered, would fail before the change (except genuinely new behavior), and belongs in the cheapest suitable tier.
- Extend the closest existing semantic owner before adding a declaration, file, or class. Do not test plumbing, stored-property round trips, display copy, layout constants, framework behavior, or trivial delegation.
- UI tests are exceptional: keep one owner for a shipping shell/entry, state-changing journey, or safety invariant that lower tiers cannot prove. Never duplicate it across smoke and exhaustive UI.
- After the change stabilizes, run the path-scoped plan once before handoff. Use narrower checks during implementation only when they provide useful feedback:

`./Scripts/verify-changed.sh --isolate --paths <file...>`

- For UI work, prefer one existing `SmokeClass/testMethod`. If none owns the behavior, apply the rubric in `Docs/Platform/Testing.md`; add coverage only when the behavior qualifies. Do not substitute bare smoke, full unit, `smoke-full`, or exhaustive UI during feature iteration.
- Agents always pass `--isolate`. Never kill foreign Xcode or Simulator processes; concurrency, worktree, lock, and diagnostics details live in `Docs/AgentContext/ci-and-project-generation.md`.
- Use `--dry-run` to preview an unfamiliar or potentially expensive route; a preview does not count as verification. Use `--quiet` when only pass/fail plus bounded failure excerpts are useful. On failure, follow `Docs/AgentContext/ci-diagnostics.md` before opening raw logs.
- At handoff, summarize the behavior changed, exact verification commands and results, skipped or failed checks, and any change-budget justification.

## Commit, push, and CI babysit

- Before commit: run path-scoped `./Scripts/verify-changed.sh --isolate --paths …` (style + package/unit/smoke/compile as routed, plus generated-output idempotence). Review and stage only the task's authored and generated files, then commit.
- After commit, before push: run `./Scripts/agent-push-gate.sh` for **generate/assert completeness against HEAD only** (catalogs / `project.pbxproj`) — it is not a style or compile gate. The pre-push hook also runs it. If generation changes files, review them, amend the commit, and rerun the gate. Use `verify-changed.sh --isolate --push-ready --paths …` only when the commit is already complete and you want the source plan and push gate in one post-commit run.
- After an explicitly requested push: run `./Scripts/agent-watch-ci.sh` for the pushed HEAD until green (quiet status polls; do not stream `gh run watch` into the agent context). On failure, read failed job names, printed check annotations, and the short log excerpt. Path-filtered green runs dispatch and watch full CI.
