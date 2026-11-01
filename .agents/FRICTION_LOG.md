# Friction Log

Centralized intake for agent pain points, confusion, and struggle while working in this codebase. Keep entries short and link to the relevant owner when extra context helps.

## How to log

1. Add a row to `## Open` when docs mislead, behavior surprises, or repeated friction appears. Review open rows when touching their area.
2. When resolved, put lasting guidance in the owning document or skill, then delete the row. Do not create a resolved-entry archive.
3. Create a knowledge pattern only when unique reusable rationale remains; avoid copying rules already enforced by an owner.

## Open

| Date | Area | Symptom (expected vs actual) |
|------|------|------------------------------|
| 2026-09-20 | Simulator inspection | Device Hub is running and the leased app launches, but Computer Use `getApp` times out (`-10005`) by both app path and bundle ID, including after a 2026-10-02 restart. The [native device-interaction skill](skills/device-interaction/SKILL.md) provides an alternative inspection route; [floating-feedback visual verification](../Docs/AgentContext/battle-presentation.md#verification-gap) remains pending. |
| 2026-10-16 | Duo inspection | Xcode 27.1 RC native captures/input can target the inactive outer display after unfolding and report `NotRun` for a running app; orientation commands can change metadata without resizing. Computer Use control activation can work while coordinate gestures fail. [Duo display routing](../Docs/Platform/SimulatorOperations.md#duo-display-routing) records the bounded capture/input checks; unfolded touch and precise cast-boundary qualification remain tooling gaps. |
| 2026-10-23 | Owned runner cancellation | After SIGTERM stopped task-owned runners, one Swift frontend and, in a separate inspection launch, nested Bash processes remained reparented to PID 1. Cleanup required confirming their task paths/process group before stopping only those owned processes. The owned nested-shell fixture passes for INT and TERM, but does not reproduce these runs; root cause remains unproven. Inspect `Scripts/lib/lock.sh` cancellation before treating a runner's exit as proof that all descendants stopped. |
