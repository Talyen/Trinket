# Audits

Re-runnable one-shot guides for coding agents. Each audit is a **procedure**, not a project tracker and not standing product requirements.

When the user cites an audit (or asks to “run the X audit”), execute that guide, fix in scope, verify, and commit. Do **not** treat uncited audits as active backlog.

## Contract (every `*Audit.md`)

| Section | Purpose |
|---------|---------|
| Goal | One sentence outcome |
| Mission / Hard stops | What to do and what not to touch |
| Probes / Targets | Concrete `rg` / script commands |
| Triage | Severity or selection rules; **cap blast radius** (one target or N fixes) |
| Fixes | Allowed remediations |
| Verification | Scripts that must pass |
| Commit / Report | Message format; summarize in the commit/PR body |

**Do not** append run results, “Done” tables, “Last execution”, or dated findings into the audit file. That turns the guide into a stale tracker. Put outcomes in the commit message or PR description.

**Prefer** existing gates (`./Scripts/check-module-boundaries.sh`, `lint.sh`, `check-ui-style.sh`, `test.sh`, `test-package.sh`) over aspirational absolute-zero metrics. Soften “zero X” goals with allowlists.

**Link** sibling audits instead of copying the same probes. Ownership:

| Concern | Owner audit |
|---------|-------------|
| Package/layer imports | `ImportCouplingBoundaryAudit.md` |
| Dead / unused symbols | `DeadCodeRatioAudit.md` |
| RNG / I/O seams | `SideEffectSurfaceAudit.md` |
| Persistence / idempotency / swallowed errors | `BehaviorHardeningAudit.md` |
| Concurrency / Sendable | `SwiftConcurrencyDataRaceAudit.md` |
| Force casts / unwraps / typing escapes | `TypeSafetyAudit.md` |
| Unit test quality & gaps | `UnitTestAudit.md` |
| UI / smoke / exhaustive test quality | `E2ETestQualityAudit.md` |
| Opportunistic defect hunt | `BugHuntingAudit.md` |
| Complexity hotspot simplification | `ComplexityReductionAudit.md` |
| Doc drift | `DocumentationStalenessAudit.md` |
| UI interaction / a11y / HIG | `UIInteractionFeedbackAudit.md` |
| Perf / memory / energy (static) | `PerformanceMemoryEnergyAudit.md` |

Standing test conventions live in `AGENTS.md` (not duplicated as an audit). CloudKit release steps live in `Docs/Platform/CloudKitPreShipChecklist.md`.

## Platform baseline

Audits must match current product rules: iOS 26+, Swift 6, `@Observable` / `@Environment` (not `ObservableObject` / `@EnvironmentObject`), `TrinketDesignSystem` chrome (see `./Scripts/check-ui-style.sh`), Swift Testing for unit targets, XCTest for `TrinketUITests` only.
