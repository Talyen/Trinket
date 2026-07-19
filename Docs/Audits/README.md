# Audits

Re-runnable one-shot guides for coding agents. An audit is neither a project tracker nor standing product requirements. Run one only when the user cites it; do not treat uncited audits as backlog.

## Shared contract

Every finding must state:

- Candidate and confirming evidence
- User or maintenance impact
- **Preferred remedy**, following delete → reuse → simplify locally → parameterize a confirmed duplicate → add an abstraction
- **Why this size**: why it is simpler than both a smaller patch that leaves the cause and a larger abstraction that adds unnecessary surface
- Expected authored production/test LOC, declaration, and file/type direction (exact estimates are unnecessary; identify increase, neutral move, or reduction)
- Matching verification

A probe hit is not a finding. **Zero findings is a successful audit result.** Never invent a fix or a structural proposal to satisfy a quota.

Unless the cited audit explicitly owns the behavior, do not change player-facing balance/copy/layout, accessibility identifiers, generated output, deterministic battle seeds, or architectural boundaries. Do not add a package/framework or weaken a test/gate to make a finding disappear.

### Right-size policy

Prefer the smallest remedy that removes the confirmed cause. Related hits may justify one cohesive change, but shared ownership alone does not justify a new seam or framework.

- **Ship in-pass:** confirmed local fixes that fully address the finding and do not paper over a larger root cause.
- **Propose and stop:** significant refactors, package moves, new seams, or architecture changes. Do not implement those in the same unsupervised pass; present the proposal and wait for approval.
- **Proposal bar** (all must hold, else do not propose):
  1. Confirmed evidence (a probe hit alone is not enough)
  2. Clear maintenance or correctness win (not taste)
  3. Local patches would leave the same class of problem nearby, or already have
  4. Remedy fits an existing owner and removes the replaced surface
  5. A generic abstraction has at least three current uses or repairs an enforced architectural boundary; predicted reuse is insufficient

### Pass shape

Keep each pass focused on one cluster or related root cause. Start with cheap, capped probes; inspect only the strongest few candidates and the source needed to confirm them. Do not dump or read a directory wholesale, run unrelated full-repo sweeps, or continue after the selected cluster is clean. A large remedy remains a proposal.

Record outcomes in the handoff/commit/PR, never in an audit. Do not append run logs, Done tables, or dated status to these guides.

### Code and test budgets

- Simplification, duplication, dead-code, and test-reduction fixes should reduce authored LOC, declarations, indirection, or executed cases. Moving code without removing the old path is not a reduction.
- Feature/correctness fixes may grow, but warnings from `./Scripts/change-budget.sh` require a necessity explanation and the simpler rejected alternative.
- Verification does not imply new coverage. Apply the test-addition gate in `Docs/Platform/Testing.md`; extend an existing semantic owner first and remove coverage made redundant.
- Parameterization is not a reduction when it merely hides the same or more expanded cases behind fewer declarations.

### Verification

After edits, run `./Scripts/verify-changed.sh --isolate --paths <changed files>`. Audit-specific checks appear only when the router cannot infer them. Do not substitute bare smoke or broad suites during iteration. Use `--quiet` for bounded output when full logs are not useful.

Prefer existing gates over aspirational absolute metrics. The only absolute-zero target is a failing enforced boundary gate; elsewhere use evidence, explicit allowlists, runtime history, and per-change ratchets.

Each audit holds only its distinct scope, confirmation rules, and domain allowlists. Shared platform policy lives in `AGENTS.md`; architecture and testing facts live in the Platform documents. Agents choose their own probes and process.

## Ownership

| Concern | Owner audit |
|---------|-------------|
| Package/layer imports | `ImportCouplingBoundaryAudit.md` |
| Dead / unused symbols | `DeadCodeRatioAudit.md` |
| RNG / I/O seams | `SideEffectSurfaceAudit.md` |
| Persistence / idempotency / swallowed errors | `BehaviorHardeningAudit.md` |
| Concurrency / Sendable | `SwiftConcurrencyDataRaceAudit.md` |
| Force casts / unwraps / typing escapes | `TypeSafetyAudit.md` |
| Unit/package test value, runtime, redundancy, and tier ownership | `UnitTestAudit.md` |
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

**Linux style under-approx:** portable SwiftLint skips SourceKit `custom_rules` and can miss findings macOS CI reports. A local style PASS is provisional — report it as such; do not claim CI lint parity. App compile (`build.sh` / package tests / unit) is similarly skipped without `xcodebuild`; say so in the audit handoff.

**`rg` path required in Cursor cloud shells:** those environments expose a readable stdin socket, so pathless `rg` waits on stdin forever. Always pass an explicit path (usually `.`) or scoped directories.
