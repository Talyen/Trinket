# Audits

Re-runnable one-shot guides for coding agents. An audit is neither a project tracker nor standing product requirements. Run one only when the user cites it; do not treat uncited audits as backlog.

## Shared contract

Every finding must state the candidate, confirming evidence, user or maintenance impact, smallest safe fix, and matching verification. A probe hit is not a finding. **Zero findings is a successful audit result.** Never invent a fix to satisfy a quota.

Keep the pass bounded: one cohesive target or a small number of confirmed, independent fixes. Use the verification row in `AGENTS.md`; do not run unrelated full-repo sweeps. Record outcomes in the commit or PR body, never in an audit. Do not append run logs, Done tables, or dated status to these guides.

Prefer existing gates over aspirational metrics. The only absolute-zero target in this set is a failing enforced boundary gate. Elsewhere, use explicit allowlists and context.

Each audit holds only its distinct scope, confirmation rules, domain allowlists, and verify hints. Shared platform policy lives in `AGENTS.md`; architecture and testing facts live in the Platform documents. Agents choose their own probes and process.

## Ownership

| Concern | Owner audit |
|---------|-------------|
| Package/layer imports | `ImportCouplingBoundaryAudit.md` |
| Dead / unused symbols | `DeadCodeRatioAudit.md` |
| RNG / I/O seams | `SideEffectSurfaceAudit.md` |
| Persistence / idempotency / swallowed errors | `BehaviorHardeningAudit.md` |
| Concurrency / Sendable | `SwiftConcurrencyDataRaceAudit.md` |
| Force casts / unwraps / typing escapes | `TypeSafetyAudit.md` |
| Unit test quality & gaps | `UnitTestAudit.md` |
| Authored declaration reduction / tier ownership | `TestSuiteReduction.md` |
| UI / smoke / exhaustive test quality | `E2ETestQualityAudit.md` |
| Opportunistic defect hunt | `BugHuntingAudit.md` |
| Doc drift | `DocumentationStalenessAudit.md` |
| UI interaction / a11y / HIG | `UIInteractionFeedbackAudit.md` |
| Custom layout/typography → Apple/SwiftUI native | `AppleNativeUIAudit.md` |
| Over-engineered / verbose / inelegant agent slop | `InelegantSlopAudit.md` |
| Device-led performance investigation | [PerformanceInvestigationPlaybook.md](../Platform/PerformanceInvestigationPlaybook.md) |

Standing conventions: [Testing.md](../Platform/Testing.md), [Architecture.md](../Platform/Architecture.md), `AGENTS.md`. CloudKit release steps: [CloudKitPreShipChecklist.md](../Platform/CloudKitPreShipChecklist.md).

## Toolchain limits

Local and CI expect **Xcode 26+**. Cloud or remote agents may lack the simulator toolchain.

| Available | Run |
|-----------|-----|
| Always | The cited audit’s static probes and relevant lightweight gates |
| Xcode / simulator present | The task-router build/test command for the changed code |
| Toolchain absent | Correct source/docs fixes still land; state exactly which build/test checks were skipped and why |

Do not fail an audit solely because Instruments, Simulator, or `xcodebuild` is unavailable.

**`rg` path required in Cursor cloud shells:** those environments expose a readable stdin socket, so pathless `rg` waits on stdin forever. Always pass an explicit path (usually `.`) or scoped directories.
