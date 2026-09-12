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

Entries point to the corrected owners. Earlier detail is retrievable with
`git log -p -- .agents/FRICTION_LOG.md`; uncommitted records remain in their task history.

| Date | Area | Resolution (commit / owner link) |
|------|------|------------------------------------|
| 2026-09-11 | Overbroad and stale guidance | Clarified [locked actions](../Docs/Product/Decisions.md), corrected [victory coverage](../TrinketUITests/README.md#speed), and centralized [battle fixture conventions](../Packages/BattleEngine/Tests/README.md#conventions). |
| 2026-09-11 | Documentation scope and duplicated policy | [Plan checks](../Docs/Plans/README.md) now warn on age and scope final closure to the task; [CloudKit readiness](../Docs/Platform/CloudKitPreShipChecklist.md#required-readiness-gates) has one ordered checklist, and [storage compatibility](../Docs/AgentContext/persistence-storage.md) protects distributed TestFlight saves. |
| 2026-09-11 | Broad routine context | [Battle contracts](../Docs/AgentContext/battle-runtime.md), [current-first documentation search](../Scripts/agent-search.py), and a short [command entry page](../Scripts/README.md) reduce unrelated reads; [scenario measurements](evals/context-efficiency.md#focused-retrieval-follow-up-2026-09-11) include follow-up costs and limitations. |
| 2026-09-11 | Documentation cleanup | Corrected stale [API guidance](../Packages/TrinketDesignSystem/Documentation/Modifiers.md), grouped [commands](../Scripts/README.md), and consolidated [memory guidance](../Docs/Platform/MemoryAndEnergyInvestigation.md); shortened resolved history with retrieval pointers. |
| 2026-09-11 | Script safety and brittle checks | [Git guard](../Scripts/git-safety-guard.mjs) refuses without stashing; [mirror](../Scripts/promote.sh) uses one owned build and destination; [lock cleanup](../Scripts/lib/lock.sh) stops workers before release. [Policy searches](../Scripts/lib/rg-check.sh) propagate failures, and regressions exercise behavior instead of guide wording or copied sorting. |
| 2026-09-11 | Documentation review | [Color guidance](../.cursor/rules/design-system-colors.mdc) now links to its canonical owner; [Testing](../Docs/Platform/Testing.md) clarifies outcome assertions; [plan retrieval](../Docs/Plans/Archived/README.md) searches both historical locations. Verification, identity, and command guidance remove duplication; talent exceptions are grouped and [support copy](../Website/index.html) states local-only saves. |
| 2026-09-11 | Competing and stale documentation | [Verification](../Docs/Platform/Verification.md#choosing-ui-verification) now owns explicit smoke selection; [audit memory](../Docs/Audits/Proposals.md) and active plans reflect current save contracts; [music routing](../Packages/TrinketAppState/README.md#music-routing) and [release prerequisites](../Docs/Platform/Release.md#shipping) point to their owners. Homestead/rendering and audit guidance retain contracts without copied tuning or repeated procedure. |
| 2026-09-11 | Save-backed detail ownership | [FeatureSupport ownership](../Packages/TrinketFeatureSupport/README.md) now distinguishes adapters submitting save commands from Persistence owning transactions; the previous blanket ban on package save mutations contradicted the existing adapters. |
| 2026-09-11 | Agent discovery and broad script routing | Resolved; see [Authored search](../Scripts/agent-search.py), [context routing](../Docs/AgentContext/README.md), [verification](../Docs/Platform/Verification.md), [Measurements](evals/context-efficiency.md). |
| 2026-09-10 | Collection border rendering | Resolved; see [Border rendering](../Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/Shared/KeywordShineBorder.swift), [shared rendering guidance](../Packages/TrinketFeatureSupport/README.md). |
| 2026-09-10 | Local Xcode result finalization | Resolved; see [Shared watchdog](../Scripts/lib/xcode-watchdog.sh), [diagnostics guidance](../Docs/AgentContext/ci-diagnostics.md). |
| 2026-09-10 | Collection performance capture | Resolved; see [Capture guidance](../Docs/Platform/PerformanceInvestigationPlaybook.md#signals). |
| 2026-09-10 | Simulator accessibility inspection | Resolved; see [simulator inspection guidance](../Docs/Platform/SimulatorOperations.md#inspection-lease-and-capture). |
| 2026-09-10 | Retained navigation accessibility | Resolved; see [the retained-layer rule](../Docs/AgentContext/ui-performance.md). |
| 2026-09-09 | Documentation drift | Resolved; see [onboarding](../README.md), [release guidance](../Docs/Platform/Release.md), [purchase sessions](../Docs/Platform/Purchases.md), [TestFlight CloudKit testing](../Docs/Platform/CloudKitPreShipChecklist.md#4-testflight-promotion), [enemy scaling](../ContentManifest/README.md#enemies-contentmanifestenemiestsv), [artwork-budget guidance](../Docs/Platform/PerformanceInvestigationPlaybook.md#artwork-budgets). |
| 2026-09-08 | UI launch lifecycle | Resolved; see [UI speed guidance](../TrinketUITests/README.md#speed). |
| 2026-09-08 | Test portfolio value | Resolved; see [Testing policy](../Docs/Platform/Testing.md#consolidation-and-retirement), [budget advisory](../Scripts/change-budget.sh). |
| 2026-09-07 | Talent catalog coverage | Resolved; see [test ownership index](../Packages/TrinketContent/Tests/README.md). |
| 2026-09-06 | Homestead save failure | [Save recovery](../Packages/TrinketPersistence/Sources/TrinketPersistence/PlayerSaveStore.swift) compensates affected graph slices without SwiftData rollback; disk-backed Food collection, reset, deferred failure, and retry regressions pass. |
| 2026-09-12 | UI result finalization | A process sample identified Xcode waiting for bulk `simctl diagnose` collection after passing tests. The [shared runner](../Scripts/xcode-runner.sh) disables that collection for routine simulator tests while preserving explicit forensic overrides; [diagnostics guidance](../Docs/AgentContext/ci-diagnostics.md) retains the watchdog as a fallback. |
| 2026-09-06 | Package test destination | [The package runner](../Scripts/test-package.sh) rejects non-simulator platforms and destinations combined with generic build-for-testing before side effects; simulator name/UUID overrides remain supported. |
| 2026-09-06 | Simulator launcher | [The launcher](../Scripts/run-simulator.sh) resolves the app from the Trinket target’s build settings and validates the product before installation; wrapper regressions cover custom product paths and missing outputs, and an isolated build/install/launch passed. |
| 2026-09-06 | Script failure evidence | [Script checks](../Scripts/test-scripts.sh) now retain failed logs with bounded excerpts; `--fast` help accurately states that all shell regressions are skipped. |
| 2026-09-05 | Balance report retention | [The sweep wrapper](../Scripts/balance-sweep.sh) retains evidence; successful runs and `--help` no longer delete the report directory. |
| 2026-09-05 | Build/test preflight | [Wrappers](../Scripts/README.md) defer slot reservation until execution, reject duplicate/unknown packages, prepare standalone package build inputs, and keep final handoff previews from executing the docs gate. |
| 2026-09-06 | Balance test result reporting | The [watchdog](../Scripts/lib/xcode-watchdog.sh) now lets individual test/suite, assertion, and test-process crash failures override later passing summaries; the [runner fixture](../Scripts/Tests/test-xcode-runner.sh) reproduces assertion failures and a process crash followed by a passing restarted run. |
| 2026-09-05 | Performance evidence | Resolved; see [playbook](../Docs/Platform/PerformanceInvestigationPlaybook.md). |
| 2026-09-05 | Skills and simulator guidance | Resolved; see [simulator operations](../Docs/Platform/SimulatorOperations.md), [evaluation guidance](evals/README.md). |
| 2026-09-05 | Generation verification | The documented freshness shortcut reported idempotence without comparing regenerated outputs. Removed it and its unused sidecar helpers; [the assertion](../Scripts/assert-generated-output.sh) now always regenerates, with regression fixtures for damaged and unstable outputs. |
| 2026-09-04 | Agent guidance | Resolved; see [agent guide](../AGENTS.md), [coverage decision](../Docs/Platform/Testing.md#coverage-decision-new-and-changed-behavior), [verification policy](../Docs/Platform/Verification.md). |
| 2026-09-06 | Audit guidance | Resolved; see [Shared audit policy](../Docs/Audits/README.md). |

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
