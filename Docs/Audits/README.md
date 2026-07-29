# Audits

Re-runnable one-shot guides for coding agents. An audit is neither a project tracker nor standing product requirements. Run one only when the user cites it; do not treat uncited audits as backlog.

## Shared contract

Every finding must state:

- Candidate and confirming evidence
- User or maintenance impact
- **Preferred remedy**, favoring smaller surface: delete → reuse → simplify locally → parameterize a confirmed duplicate → add an abstraction
- **Why this size**: why it is simpler than both a smaller patch that leaves the cause and a larger abstraction that adds unnecessary surface
- Expected authored production/test LOC, declaration, and file/type direction (exact estimates are unnecessary; identify increase, neutral move, or reduction)
- Matching verification

A candidate signal is not a finding. **Zero findings is a successful audit result.** Never invent a fix or a structural proposal to satisfy a quota.

### Severity scale

Audits share one scale and map their domain examples onto it:

| Sev | Meaning |
|-----|---------|
| P0 | Fix now: crash, data loss/corruption, flaky CI, failing enforced gate |
| P1 | Fix now: confirmed wrong behavior or clear, measured maintenance cost |
| P2 | Fix when confirmed and scoped: tier misplacement, degraded UX, undocumented unsafe escape |
| P3 | Optional: style/consistency; only when trivial or already touching that surface |

A hit whose severity belongs to another audit's concern is routed there, not tracked as a low-severity finding here.

Unless the cited audit explicitly owns the behavior, do not change player-facing balance/copy/layout, accessibility identifiers, generated output, deterministic battle seeds, or architectural boundaries. Do not add a package/framework or weaken a test/gate to make a finding disappear.

### Right-size policy

Prefer the smallest remedy that removes the confirmed cause. Related hits may justify one cohesive change, but shared ownership alone does not justify a new seam or framework.

- **Ship in-pass:** confirmed local fixes that fully address the finding and do not paper over a larger root cause.
- **Propose and stop:** significant refactors, package moves, new seams, or architecture changes. Do not implement those in the same unsupervised pass; present the proposal, record it in [Proposals.md](Proposals.md), and wait for approval.
- **Proposal bar** (all must hold, else do not propose):
  1. Confirmed evidence (a signal alone is not enough)
  2. Clear maintenance or correctness win (not taste)
  3. Local patches would leave the same class of problem nearby, or already have
  4. Remedy fits an existing owner and removes the replaced surface
  5. A generic abstraction has at least three current uses or repairs an enforced architectural boundary; predicted reuse is insufficient

### Pass shape

Inventory confirmed findings and, before unsupervised multi-finding fixes, write an implementation plan covering them. If overall scope is large, break the plan into distinct phases. Do not dump or read a directory wholesale or run unrelated full-repo sweeps.

Record outcomes in the handoff/commit/PR, never in an audit guide. Do not append run logs, Done tables, or dated status to these guides.

Agents choose their own probes and process. Audits state invariants, evidence bars, and success criteria — not investigation choreography.

### Run memory

[Proposals.md](Proposals.md) is the only durable state between runs: the routine-scope baseline commit, open proposals awaiting approval, rejected proposals, and accepted non-findings. Read it during triage and skip listed items unless new evidence supersedes an entry; write new proposals and accepted non-findings there, following its hygiene rules.

### Run scope and cadence

Routine passes (every few days) default their candidate inventory to code changed since the baseline commit in [Proposals.md](Proposals.md); run whole-codebase passes on request or at a longer interval, then advance the baseline. Recent-change scope fits the defect classes agent sessions re-seed fastest: slop ceremony, dead code, dual paths, duplicate surfaces, ownership drift, typing escapes, effect-seam leaks, concurrency escapes, persistence regressions, test-portfolio growth, and opportunistic bugs.

`AuthoredMassGrowthAudit`, `ChangeLocalityContextEfficiencyAudit`, and `DocumentationStalenessAudit` are retrospective inventories — prefer whole-repo passes at a longer cadence (weekly or on request) over including them in every routine rotation.

### Orchestrated runs

When a user requests multiple audits or subagent implementation, keep one root orchestrator responsible for shared prereads, candidate deduplication, finding confirmation, the implementation plan, edit ownership, final review, and integrated verification.

- Delegate only confirmed, independent implementation slices. Use an Explorer only for a bounded investigation that does not repeat the root inventory.
- Never give a subagent the full conversation by default. Use no inherited turns or the smallest useful recent-turn slice; rely on a task brief and repository sources for durable context.
- A task brief must name the owning audit, confirmed evidence, intended remedy, exact files/symbols the agent owns, hard stops, and the cheapest matching verification. Do not ask the agent to rediscover the problem or rerun broad probes.
- Keep concurrent write ownership disjoint. Prefer one or two implementation agents at a time; additional agents must provide a real independent latency win.
- Subagents run targeted checks for their own slice and return only changed paths, behavior, verification status, and blockers. Do not return raw diffs, source dumps, or full build/test logs.
- The root reviews every diff and runs the canonical path-scoped gate once across the integrated changed paths. Do not multiply the same full suite across workers and the root.
- Keep command output bounded: pass explicit paths to searches, prefer quiet or summary modes, and inspect focused diagnostics only after a failure. Save or summarize long logs instead of injecting them into agent context.

### Audit template

Each audit should include only:

- **Goal / Intent** — outcomes of a successful pass
- **Hard stops** — scope boundaries and deferrals
- **Domain rules / allowlists / ownership** — repo invariants
- **Evidence bar / severity** — what counts as a confirmed finding and how to prioritize it
- **Success / verifiability** — measurable direction when applicable

Optional **Example signals** may list non-exhaustive defect *classes* (not search recipes, named-file checklists, or required tool sequences). Do not require Probe hints, numbered confirm-before-fixing workflows, or “run script X first” as audit steps. Shared planning and remedy-sizing policy lives here; do not restate it in every Intent.

### Code and test budgets

- Simplification, duplication, dead-code, and test-reduction fixes should reduce authored LOC, declarations, indirection, or executed cases. Moving code without removing the old path is not a reduction.
- Feature/correctness fixes may grow, but warnings from `./Scripts/change-budget.sh` require a necessity explanation and the simpler rejected alternative.
- Verification does not imply new coverage. Apply the test-addition gate in `Docs/Platform/Testing.md`; extend an existing semantic owner first and remove coverage made redundant.
- Parameterization is not a reduction when it merely hides the same or more expanded cases behind fewer declarations.

### Verification

Changed paths must pass path-scoped verification; `./Scripts/verify-changed.sh --isolate --paths <changed files>` is the canonical gate. Audit-specific checks appear only when the router cannot infer them. Do not substitute bare smoke or broad suites during iteration.

Prefer existing gates over aspirational absolute metrics. The only absolute-zero target is a failing enforced boundary gate; elsewhere use evidence, explicit allowlists, runtime history, and per-change ratchets.

Each audit holds only its distinct scope, confirmation rules, and domain allowlists. Shared platform policy lives in `AGENTS.md`; architecture and testing facts live in the Platform documents.

## Ownership

| Concern | Owner audit |
|---------|-------------|
| Dead / unused symbols | `DeadCodeRatioAudit.md` |
| Live dual paths / retained compatibility shims | `DualPathRetentionAudit.md` |
| Authored mass / growth hotspots (retrospective) | `AuthoredMassGrowthAudit.md` |
| RNG / I/O seams | `SideEffectSurfaceAudit.md` |
| Persistence / idempotency / swallowed errors | `BehaviorHardeningAudit.md` |
| Concurrency / Sendable | `SwiftConcurrencyDataRaceAudit.md` |
| Force casts / unwraps / typing escapes | `TypeSafetyAudit.md` |
| Unit/package test value, runtime, redundancy, fixture sprawl, and tier ownership | `UnitTestAudit.md` |
| UI / smoke / exhaustive test quality | `E2ETestQualityAudit.md` |
| Opportunistic defect hunt | `BugHuntingAudit.md` |
| Doc drift | `DocumentationStalenessAudit.md` |
| UI interaction / a11y / HIG | `UIInteractionFeedbackAudit.md` |
| Custom layout/typography → Apple/SwiftUI native | `AppleNativeUIAudit.md` |
| Over-engineered / verbose / inelegant agent slop | `InelegantSlopAudit.md` |
| Copy-paste feature screens / shells | `DuplicateFeatureSurfaceAudit.md` |
| Misplaced logic in AppState / hubs / mega-views | `StateGravityOwnershipAudit.md` |
| Change locality / agent context, guidance-surface, and verification efficiency | `ChangeLocalityContextEfficiencyAudit.md` |
| Device-led performance investigation | [PerformanceInvestigationPlaybook.md](../Platform/PerformanceInvestigationPlaybook.md) |

### Confusable pairs

This table is the canonical routing for commonly confused hits. Audit guides keep at most their two or three closest neighbors and defer the rest here; one problem produces one finding under one owner.

| If the hit is… | Owner |
|----------------|-------|
| Zero live consumers | DeadCodeRatio |
| Reachable twin path or forwarding shim (correct owner) | DualPathRetention |
| Single surviving path that is pure ceremony | InelegantSlop |
| Wrong semantic owner, with or without a leftover twin | StateGravityOwnership (move, then delete the old path) |
| Large or mixed-jobs surface with correct owner and a single path | AuthoredMassGrowth |
| Copy-paste product screens or repeated view scaffolding across 3+ files | DuplicateFeatureSurface (including repeated grid scaffolding spotted during AppleNativeUI passes) |
| Raw layout/typography literals without a structural twin | AppleNativeUI |
| Duplicate, weak, or over-expanded test coverage | UnitTest (unit/package) or E2ETestQuality (UI tiers) |
| Recurring co-touch, duplicated policy/commands, or guidance-surface duplication | ChangeLocalityContextEfficiency |
| Silent persistence/transition failure without ownership drift | BehaviorHardening |
| Effect primitive outside its allowlisted seam | SideEffectSurface |

Package/layer imports are continuously enforced by [Architecture.md](../Platform/Architecture.md) and `./Scripts/check-module-boundaries.sh`; they are not a user-invoked audit.

Standing conventions: [Testing.md](../Platform/Testing.md), [Architecture.md](../Platform/Architecture.md), `AGENTS.md`. CloudKit release steps: [CloudKitPreShipChecklist.md](../Platform/CloudKitPreShipChecklist.md).

## Toolchain limits

Local and CI expect **Xcode 26+**. Cloud or remote agents may lack the simulator toolchain.

| Available | Expectation |
|-----------|-------------|
| Always | Run available lightweight gates relevant to the change; report what was skipped |
| Xcode / simulator present | Path-scoped build/test for the changed code |
| Toolchain absent | Correct source/docs fixes still land; state exactly which build/test checks were skipped and why |

Do not fail an audit solely because Instruments, Simulator, or `xcodebuild` is unavailable.

**Linux style under-approx:** portable SwiftLint skips SourceKit `custom_rules` and can miss findings macOS CI reports. A local style PASS is provisional — report it as such; do not claim CI lint parity. App compile (`build.sh` / package tests / unit) is similarly skipped without `xcodebuild`; say so in the audit handoff.

**`rg` path required in Cursor cloud shells:** those environments expose a readable stdin socket, so pathless `rg` waits on stdin forever. Always pass an explicit path (usually `.`) or scoped directories.
