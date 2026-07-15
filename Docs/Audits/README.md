# Audits

Re-runnable one-shot guides for coding agents. An audit is neither a project tracker nor standing product requirements. Run one only when the user cites it; do not treat uncited audits as backlog.

## Shared contract

Every finding must state:

- Candidate and confirming evidence
- User or maintenance impact
- **Preferred remedy** (right-sized: local fix, cohesive refactor, or architecture change)
- **Why this size** (why a smaller patch would be incomplete, recurring, or whack-a-mole — or why local is enough)
- Matching verification

A probe hit is not a finding. **Zero findings is a successful audit result.** Never invent a fix or a structural proposal to satisfy a quota.

### Right-size policy

Prefer one root-cause remedy over N sibling micro-patches when hits share ownership, invariants, or a duplicated pattern. Optimize for pragmatic, elegant code — not the smallest possible diff.

- **Ship in-pass:** confirmed local fixes that fully address the finding and do not paper over a larger root cause.
- **Propose and stop:** significant refactors, package moves, new seams, or architecture changes. Do not implement those in the same unsupervised pass; present the proposal and wait for approval.
- **Proposal bar** (all must hold, else do not propose):
  1. Confirmed evidence (a probe hit alone is not enough)
  2. Clear maintenance or correctness win (not taste)
  3. Local patches would leave the same class of problem nearby, or already have
  4. Remedy fits existing Architecture / DesignSystem / package ownership — not a new framework for one call site

### Pass shape

Keep each pass focused on one cluster or related root cause. That cluster’s preferred remedy may be large *as a proposal*. Do not run unrelated full-repo sweeps. Use the verification row in `AGENTS.md`. Record outcomes in the commit or PR body, never in an audit. Do not append run logs, Done tables, or dated status to these guides.

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
| Copy-paste feature screens / shells | `DuplicateFeatureSurfaceAudit.md` |
| Misplaced logic in AppState / hubs / mega-views | `StateGravityOwnershipAudit.md` |
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
