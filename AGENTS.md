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

## Verification

Before handoff, run the path-scoped checks:

`./Scripts/verify-changed.sh --paths <file...>`

Use `--dry-run` only when previewing an unfamiliar or potentially expensive route. Do not parallelize `test.sh` wrapper invocations.

If verification fails, follow `Docs/AgentContext/ci-diagnostics.md` and use its structured reports before opening raw logs.
