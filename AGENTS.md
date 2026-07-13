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

- For a small UI feature confined to one screen or flow, run only the closest focused smoke target selected by the router (`./Scripts/test.sh smoke <SmokeClass>`). Prefer `SmokeClass/testMethod` when one method directly owns the behavior. Do not run bare smoke, the full unit suite, `smoke-full`, exhaustive UI tests, or global style checks for that iteration; those belong to pre-push or CI gates.
- If no existing smoke class closely covers the changed behavior, add or update one focused smoke test and run only that class. Do not use the unrelated Homestead canary as a substitute.
- Before starting a build or test wrapper, check whether another repository build or test run is already active.
- Never terminate a build or test process you did not start merely to run your own checks. Wait 30 seconds, check again, and repeat until the active run finishes before starting yours.
- You may terminate only processes started by your own agent. If another agent's run appears stale or hung, inspect its elapsed time and available output, then report or coordinate the suspected hang instead of killing it. Do not use broad process cleanup commands such as `pkill`, `killall`, or simulator shutdown while another run may be active.

If verification fails, follow `Docs/AgentContext/ci-diagnostics.md` and use its structured reports before opening raw logs.
