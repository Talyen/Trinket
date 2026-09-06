# Friction Log

Centralized intake for agent pain points, confusion, and struggle while working in this codebase. Keep entries short — one line in the table is enough. Use the expanded template only when extra context helps.

Add a row to `Open` when docs mislead, behavior surprises, or repeated friction appears. Move it to `Resolved` with a link to the fix when addressed. Review Open rows when touching their area. Close resolved entries with a link to the corrected owner; create a knowledge pattern or skill instruction only when a reusable lesson remains.

## How to log

1. Add a row to `## Open` below.
2. For longer context, add a `### YYYY-MM-DD — short slug` subsection under `## Details` using the template at the bottom.
3. When resolved, move the row to `## Resolved` and include a commit, PR, corrected owner, or `knowledge/patterns/<name>.md` link.

## Open

| Date | Area | Symptom (expected vs actual) |
|------|------|------------------------------|

## Resolved

| Date | Area | Resolution (commit / owner link) |
|------|------|------------------------------------|
| 2026-09-06 | Homestead save failure | [Save recovery](../Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore.swift) compensates affected graph slices without SwiftData rollback; disk-backed Food collection, reset, deferred failure, and retry regressions pass. |
| 2026-09-06 | UI result finalization | [Diagnostics guidance](../Docs/AgentContext/ci-diagnostics.md) documents log-proven success, incomplete bundles, evidence retention, and separate motion recording. Existing watchdog regressions verify bounded completion and failure precedence; the Xcode finalization hang remains a supported tooling limitation. |
| 2026-09-06 | Package test destination | [The package runner](../Scripts/test-package.sh) rejects non-simulator platforms and destinations combined with generic build-for-testing before side effects; simulator name/UUID overrides remain supported. |
| 2026-09-06 | Simulator launcher | [The launcher](../Scripts/run-simulator.sh) resolves the app from the Trinket target’s build settings and validates the product before installation; wrapper regressions cover custom product paths and missing outputs, and an isolated build/install/launch passed. |
| 2026-09-06 | Script failure evidence | [Script checks](../Scripts/test-scripts.sh) now retain failed logs with bounded excerpts; `--fast` help accurately states that all shell regressions are skipped. |
| 2026-09-05 | Balance report retention | [The sweep wrapper](../Scripts/balance-sweep.sh) retains evidence; successful runs and `--help` no longer delete the report directory. |
| 2026-09-05 | Build/test preflight | [Wrappers](../Scripts/README.md) defer slot reservation until execution, reject duplicate/unknown packages, prepare standalone package build inputs, and keep final handoff previews from executing the docs gate. |
| 2026-09-06 | Balance test result reporting | The [watchdog](../Scripts/lib/xcode-watchdog.sh) now lets individual test/suite, assertion, and test-process crash failures override later passing summaries; the [runner fixture](../Scripts/Tests/test-xcode-runner.sh) reproduces assertion failures and a process crash followed by a passing restarted run. |
| 2026-09-05 | Performance evidence | The [playbook](../Docs/Platform/PerformanceInvestigationPlaybook.md) now documents retained evidence, consistent observation/enforcement, and missing reveal coverage; it no longer presents post-reveal idle samples as reveal measurements or prescribes a fixed diagnostic order. |
| 2026-09-05 | Skills and simulator guidance | Removed fixed-slot capture advice and default-mirror claims; [simulator operations](../Docs/Platform/SimulatorOperations.md) now distinguishes selection from a held lease and documents opt-in mirroring. Simplified skill triggers and [evaluation guidance](evals/README.md) without requiring a promotion log for every edit. |
| 2026-09-05 | Generation verification | The documented freshness shortcut reported idempotence without comparing regenerated outputs. Removed it and its unused sidecar helpers; [the assertion](../Scripts/assert-generated-output.sh) now always regenerates, with regression fixtures for damaged and unstable outputs. |
| 2026-09-04 | Agent guidance | Removed conflicting workflow absolutes and duplicate root policy; corrected the coverage decision to permit extending existing tests. See [agent guide](../AGENTS.md), [coverage decision](../Docs/Platform/Testing.md#coverage-decision-new-and-changed-behavior), and [verification policy](../Docs/Platform/Verification.md). |

| 2026-09-06 | Audit guidance | [Shared audit policy](../Docs/Audits/README.md) now uses whole-concern scope and impact-based evidence; domain guides distinguish candidate syntax from defects and preserve canonical owners. Removed the cross-audit baseline that could imply unreviewed coverage. |

## Details

_Add expanded entries here when the table row is not enough. Keep the table as the index._

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
