# Friction Log

Centralized intake for agent pain points, confusion, and struggle while working in this codebase. Keep entries short — one line in the table is enough. Use the expanded template only when extra context helps.

Add a row to `Open` when docs mislead, behavior surprises, or repeated friction appears. Move it to `Resolved` with a link to the fix when addressed. Review Open rows when touching their area. Close resolved entries with a link to the corrected owner; create a knowledge pattern or skill instruction only when a reusable lesson remains.

## How to log

1. Add a row to `## Open` below.
2. For longer context, add a `### YYYY-MM-DD — short slug` subsection under `## Details` using the template at the bottom.
3. When resolved, move the row to `## Resolved` and include a commit, PR, or `knowledge/patterns/<name>.md` link.

## Open

| Date | Area | Symptom (expected vs actual) |
|------|------|------------------------------|
| 2026-09-05 | Homestead save failure | On the iOS 27 simulator, collecting persisted pending Food with `forcesNextSaveFailure` aborts in the existing `PlayerSaveStore.restoreSnapshot` rollback: SwiftData casts `DefaultStoreSnapshotValueFuture` to `[HomesteadPendingProductionModel]`. Reproduce with Food 900 / pending Food 10 and a forced collect-save failure; animation does not start. Save recovery needs separate investigation. |
| 2026-09-05 | UI result finalization | Homestead UI assertions finish, but `xcodebuild` does not finalize the result bundle even with a 60-second post-suite idle allowance. The watchdog infers the result from the test log; retain logs and simulator recordings separately when investigating motion. |
| 2026-09-05 | Package test destination | `test-package.sh --destination platform=macOS` accepts the destination but forces `-sdk iphonesimulator`, so tests build and then cannot load the macOS bundle. Use its default simulator destination for this runner. |
| 2026-09-04 | Simulator launcher | `run-simulator.sh --isolate` builds successfully but cannot install: it assumes products under agent DerivedData, while `xcodebuild -showBuildSettings` resolves `BUILT_PRODUCTS_DIR` to the shared `.DerivedData/Build/Products/Debug-iphonesimulator`; use the resolved product path for inspection. |

## Resolved

| Date | Area | Resolution (commit / owner link) |
|------|------|------------------------------------|
| 2026-09-06 | Script failure evidence | [Script checks](../Scripts/test-scripts.sh) now retain failed logs with bounded excerpts; `--fast` help accurately states that all shell regressions are skipped. |
| 2026-09-05 | Balance report retention | [The sweep wrapper](../Scripts/balance-sweep.sh) retains evidence; successful runs and `--help` no longer delete the report directory. |
| 2026-09-05 | Build/test preflight | [Wrappers](../Scripts/README.md) defer slot reservation until execution, reject duplicate/unknown packages, prepare standalone package build inputs, and keep final handoff previews from executing the docs gate. |
| 2026-09-06 | Balance test result reporting | The [watchdog](../Scripts/lib/xcode-watchdog.sh) now lets individual test/suite, assertion, and test-process crash failures override later passing summaries; the [runner fixture](../Scripts/Tests/test-xcode-runner.sh) reproduces assertion failures and a process crash followed by a passing restarted run. |
| 2026-09-05 | Performance evidence | The [playbook](../Docs/Platform/PerformanceInvestigationPlaybook.md) now documents retained evidence, consistent observation/enforcement, and missing reveal coverage; it no longer presents post-reveal idle samples as reveal measurements or prescribes a fixed diagnostic order. |
| 2026-09-05 | Skills and simulator guidance | Removed fixed-slot capture advice and default-mirror claims; [simulator operations](../Docs/Platform/SimulatorOperations.md) now distinguishes selection from a held lease and documents opt-in mirroring. Simplified skill triggers and [evaluation guidance](evals/README.md) without requiring a promotion log for every edit. |
| 2026-09-05 | Generation verification | The documented freshness shortcut reported idempotence without comparing regenerated outputs. Removed it and its unused sidecar helpers; [the assertion](../Scripts/assert-generated-output.sh) now always regenerates, with regression fixtures for damaged and unstable outputs. |
| 2026-09-04 | Agent guidance | Removed conflicting workflow absolutes and duplicate root policy; corrected the coverage decision to permit extending existing tests. See [agent guide](../AGENTS.md), [coverage decision](../Docs/Platform/Testing.md#coverage-decision-new-and-changed-behavior), and [verification policy](../Docs/Platform/Verification.md). |

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
