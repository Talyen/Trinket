# Friction Log

Centralized intake for agent pain points, confusion, and struggle while working in this codebase. Keep entries short and link to the relevant owner when extra context helps.

## How to log

1. Add a row to `## Open` when docs mislead, behavior surprises, or repeated friction appears. Review open rows when touching their area.
2. When resolved, put lasting guidance in the owning document or skill, then delete the row. Do not create a resolved-entry archive.
3. Create a knowledge pattern only when unique reusable rationale remains; avoid copying rules already enforced by an owner.

## Open

| Date | Area | Symptom (expected vs actual) |
|------|------|------------------------------|
| 2026-10-23 | Owned runner cancellation | After SIGTERM stopped task-owned runners, one Swift frontend and, in a separate inspection launch, nested Bash processes remained reparented to PID 1. Cleanup required confirming their task paths/process group before stopping only those owned processes. The owned nested-shell fixture passes for INT and TERM, but does not reproduce these runs; root cause remains unproven. Inspect `Scripts/lib/lock.sh` cancellation before treating a runner's exit as proof that all descendants stopped. |
