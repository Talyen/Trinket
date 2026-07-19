# Trinket agent guide

Portrait-first iOS fantasy turn-based card combat.

## Guardrails

- These rules apply repository-wide. The nearest nested `AGENTS.md` adds path-specific instructions without relaxing root safety, boundary, or generated-output rules.
- Preserve existing work. Do not clean, revert, overwrite, stage, or include unrelated changes.
- Keep work within the requested scope. Report verification failures and skipped checks.
- Treat checked-in project configuration as the toolchain source of truth. Do not add legacy-platform compatibility or UIKit bridges when current SwiftUI provides a first-party solution.
- Never hand-edit generated code, processed assets/resources, `.DerivedData/`, `.tools/`, or the Xcode project. Edit authored inputs and use the routed generation checks.
- Work locally on `main`. Do not create or switch branches, commit, push, tag, or open a PR unless explicitly requested. For requested commit or release work, read `Scripts/README.md`.

## Change discipline

- Implement the smallest complete change. Do not add speculative extension points, compatibility paths, defensive layers for impossible states, or adjacent cleanup.
- Prefer, in order: delete → reuse → simplify locally → parameterize a confirmed duplicate → add an abstraction.
- Modify the existing owner before adding a file, type, protocol, manager, helper, wrapper, or configuration object. A generic abstraction needs at least three current uses or an enforced architectural boundary; predicted future reuse is insufficient.
- Refactors remove the replaced path. Do not leave forwarding wrappers, parallel implementations, or duplicate tests unless compatibility explicitly requires them.
- Treat authored production and test surface as budgets. Unusual growth is advisory, not a license to compress code: report the necessity and the simpler alternative rejected when `./Scripts/change-budget.sh` warns.

## Task routing

Once the likely paths are known, run:

`./Scripts/agent-context.sh --agent --paths <file...>`

Read only the nested guides, context cards, and skills it selects. Rerun it only if the task crosses into another area.

## Test and verification discipline

- Verification does not imply authoring a test. Add or expand coverage only for a distinct consequential behavior or invariant that lacks an owner, would fail before the change (except genuinely new behavior), and belongs in the cheapest suitable tier.
- Extend an existing semantic owner before adding a declaration, file, or class. Do not test plumbing, stored-property round trips, display copy, layout constants, framework behavior, or trivial delegation.
- UI tests are exceptional: keep one owner for a shipping shell/entry, state-changing journey, or safety invariant that lower tiers cannot prove. Never duplicate it across smoke and exhaustive UI.
- After the change stabilizes, run the path-scoped plan once before handoff. Use narrower checks during implementation only when they provide useful feedback:

`./Scripts/verify-changed.sh --isolate --paths <file...>`

- For UI work, prefer one existing `SmokeClass/testMethod`. If none owns the behavior, apply the rubric in `Docs/Platform/Testing.md`; add coverage only when the behavior qualifies. Do not substitute bare smoke, full unit, `smoke-full`, or exhaustive UI during feature iteration.
- Agents always pass `--isolate`. Never kill foreign Xcode or Simulator processes; concurrency, worktree, lock, and diagnostics details live in `Docs/AgentContext/ci-and-project-generation.md`.
- Use `--dry-run` only for an unfamiliar or potentially expensive route and `--quiet` when only pass/fail plus bounded failure excerpts are useful. On failure, follow `Docs/AgentContext/ci-diagnostics.md` before opening raw logs.

## Commit, push, and CI babysit

- Before commit/push: `./Scripts/agent-push-gate.sh` (or `verify-changed.sh --isolate --push-ready --paths …`).
- After push to `main`: `./Scripts/agent-watch-ci.sh` until green (quiet status polls; do not stream `gh run watch` into the agent context). On failure, read the printed excerpt / failed job names only. Path-filtered green runs dispatch and watch full CI.

Never “fix” generated drift by hand-editing `project.pbxproj` or committing lossy asset re-encodes from CI. Regenerate with pinned tools (`./Scripts/ensure-ci-tools.sh` + `./Scripts/generate.sh --force-xcodegen`); use `FORCE_ASSET_REENCODE=1` only for intentional binary refreshes.
