# Friction Log

Centralized intake for agent pain points, confusion, and struggle while working in this codebase. Keep entries short — one line in the table is enough. Use the expanded template only when extra context helps.

## How to log

1. Add a row to `## Open` when docs mislead, behavior surprises, or repeated friction appears. Review open rows when touching their area.
2. For longer context, add a `### YYYY-MM-DD — short slug` subsection under `## Details` using the template below.
3. When resolved, put any lasting guidance in the owning document or skill, then delete the row and associated details. Do not create a resolved-entry archive.
4. Create a knowledge pattern only when unique reusable rationale remains; avoid copying rules already enforced by an owner.

## Open

| Date | Area | Symptom (expected vs actual) |
|------|------|------------------------------|
| 2026-09-20 | Simulator inspection | Device Hub is running and the leased app launches, but Computer Use `getApp` times out (`-10005`) by both app path and bundle ID, including after a 2026-10-02 restart. The [native device-interaction skill](skills/device-interaction/SKILL.md) provides an alternative inspection route; [floating-feedback visual verification](../Docs/AgentContext/battle-presentation.md#verification-gap) remains pending. |

## Details

_Add expanded entries here when the table row is not enough. Keep the table as the index._

### 2026-10-02 — Device Hub attachment diagnosis

- **Context:** macOS 27.0, Xcode 27.0 (`27A266a`), Computer Use helper
  `26.924.1001281`; requested investigation of the recurring `-10005` timeout.
- **Evidence:** Finder inspection works and the helper passes signature verification.
  Apple's Accessibility Inspector lists Device Hub with PID `0` while the OS process
  is alive. LaunchServices lacks the normal PID/check-in fields, including after a
  normal macOS launch before Computer Use touches the new instance. A restart did
  not fix `getApp`; the cause of the timeout remains unproven.
- **Alternative:** Xcode's native route captured meaningful hierarchies and
  screenshots, tapped Settings at a hierarchy hit point, and returned Home on the
  managed agent simulator. The repo now vendors Apple's
  [device-interaction workflow](skills/device-interaction/SKILL.md), adapted to
  Trinket's leases and CI policy. This is tooling evidence, not a completed visual
  review of floating combat feedback or Battle Transitions.

### Expanded entry template

Copy and fill when needed:

```
### YYYY-MM-DD — short slug

- **Context:** what you were trying to do
- **Expected:** what you expected to happen / where you expected to find it
- **Actual / confusion:** what happened or what was confusing
- **Impact:** how it slowed you down or affected the task
- **Suggestion (optional):** what would have helped
```
