# Audits

Re-runnable one-shot guides for coding agents. An audit is neither a project tracker nor standing product requirements. Run one only when the user cites it; do not treat uncited audits as backlog.

## Shared contract

Every finding must state:

- Candidate and confirming evidence
- User or maintenance impact
- **Preferred remedy**, favoring the most pragmatic surface — the cleanest long-term ownership, ordered as delete → reuse → simplify locally → parameterize a confirmed duplicate → add an abstraction. Choose the rung that best fits the architecture, not automatically the shortest.
- **Why this size**: why it is the most pragmatic fit compared to both a smaller patch that leaves the cause and a larger abstraction that adds unnecessary surface
- Expected authored production/test LOC, declaration, and file/type direction (exact estimates are unnecessary; identify increase, neutral move, or reduction)
- Matching verification

A candidate signal is not a finding. **Zero findings is a successful audit result.** Never invent a fix or a structural proposal to satisfy a quota.

### Evidence cone and bounded breadth

Start with the selected audit's routine inventory, then follow confirmed evidence far enough to understand and remove the cause. The evidence cone may include callers, implementations, sibling instances, tests, authored configuration, generated-input manifests, and documentation tied to the same behavior or invariant. A selected audit does not become a general repository review merely because its evidence crosses files or packages.

Once one instance is confirmed, inventory materially similar instances in the same semantic owner or under the same invariant. Fix the whole confirmed cluster when consistency is necessary, the change follows existing architecture, and verification remains bounded. Otherwise phase the confirmed remainder or propose the part that crosses the approval boundary below. Do not stop at the first hit when doing so would leave the same defect or obsolete path immediately adjacent.

Cross-audit routing prevents duplicate findings; it does not suppress root-cause work. Do not run an uncited sibling audit's full inventory, but a remedy may include an adjacent concern owned by another audit when it is necessary to complete the same confirmed fix. Attribute that portion to its canonical owner in the plan and handoff.

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

Prefer the most pragmatic remedy that fully removes the confirmed cause — the cleanest architectural fit, not the narrowest diff. A cohesive change that restores the correct owner and removes the replaced surface is preferred over a minimal patch that papers over the root cause. Related hits may justify one cohesive change, but shared ownership alone does not justify a new seam or framework.

- **Ship in-pass:** confirmed bounded fixes that fully address the finding and do not paper over a larger root cause. They may span files or packages when they restore an owner already prescribed by Architecture, remove one cohesive cluster, migrate every affected caller, and have bounded verification.
- **Propose and stop:** a new architectural boundary or package, a player-facing product-policy decision, a live wire-format or compatibility migration, or a high-risk rewrite that is difficult to reverse or verify as one bounded change. Present the proposal, record it in [Proposals.md](Proposals.md), and wait for approval. Size alone does not force a proposal when the remedy follows an existing owner and can be phased safely.
- **Proposal bar** (all must hold, else do not propose):
  1. Confirmed evidence (a signal alone is not enough)
  2. Clear maintenance or correctness win (not taste)
  3. Local patches would leave the same class of problem nearby, or already have
  4. Remedy fits an existing owner and removes the replaced surface
  5. A generic abstraction has at least three current uses or repairs an enforced architectural boundary; predicted reuse is insufficient

### Pass shape

Inventory confirmed findings and, before unsupervised multi-finding fixes, write an implementation plan covering them. Include the evidence cone, confirmed cluster, canonical owner, migration/removal boundary, and matching verification. If overall scope is large, break the plan into distinct phases. Do not dump or read a directory wholesale or run unrelated full-repo sweeps.

Record outcomes in the handoff/commit/PR, never in an audit guide. Do not append run logs, Done tables, or dated status to these guides.

Agents choose their own probes and process. Audits state invariants, evidence bars, and success criteria — not investigation choreography.

### Run memory

[Proposals.md](Proposals.md) is the only durable state between runs: the routine-scope baseline commit, open proposals awaiting approval, rejected proposals, and accepted non-findings. Read it during triage and skip listed items unless new evidence supersedes an entry; write new proposals and accepted non-findings there, following its hygiene rules.

### Run scope and cadence

Routine passes (every few days) use a two-ring inventory. Ring 1 is code changed since the baseline commit in [Proposals.md](Proposals.md) plus its directly affected semantic owners. Ring 2 is the evidence cone of any confirmed Ring 1 candidate: relevant callers, implementations, sibling instances, tests, authored configuration, manifests, and documentation. Ring 2 is triggered by evidence, not scanned speculatively. Run whole-codebase passes on request or at a longer interval, then advance the baseline. This scope fits the defect classes agent sessions re-seed fastest while allowing a pass to remove a confirmed cause completely.

`02_MaintenanceSurfaceLocalityAudit.md` and `07_DocumentationStalenessAudit.md` are retrospective inventories — prefer whole-repo passes at a longer cadence (weekly or on request) over including them in every routine rotation.

Multi-audit orchestration (subagent briefs, disjoint writes, one integrated handoff): [.agents/skills/run-audits/SKILL.md](../../.agents/skills/run-audits/SKILL.md).

### Audit template

Each audit should include only:

- **Goal / Intent** — outcomes of a successful pass
- **Hard stops** — scope boundaries and deferrals
- **Domain rules / allowlists / ownership** — repo invariants
- **Evidence bar / severity** — what counts as a confirmed finding and how to prioritize it
- **Discovery expansion / remediation envelope** — only when the domain needs rules beyond the shared evidence-cone and bounded-fix policy
- **Success / verifiability** — measurable direction when applicable

Optional **Example signals** may list non-exhaustive defect *classes* (not search recipes, named-file checklists, or required tool sequences). Do not require Probe hints, numbered confirm-before-fixing workflows, or “run script X first” as audit steps. Shared planning and remedy-sizing policy lives here; do not restate it in every Intent.

Numbered guides should link back here for severity, evidence-cone breadth,
proposal sizing, code/test budgets, verification, and cross-audit routing. Keep
those guides domain-specific; repeated shared contract text is documentation
drift, not extra safety.

### Code and test budgets

- Simplification, duplication, dead-code, and test-reduction fixes should reduce authored LOC, declarations, indirection, or executed cases. Moving code without removing the old path is not a reduction.
- Feature/correctness fixes may grow, but warnings from `./Scripts/change-budget.sh` require a necessity explanation and the simpler rejected alternative.
- Verification does not imply new coverage. Apply the test-addition gate in `Docs/Platform/Testing.md`; extend an existing semantic owner first and remove coverage made redundant.
- Parameterization is not a reduction when it merely hides the same or more expanded cases behind fewer declarations.

### Verification

Changed paths must pass path-scoped verification; `./Scripts/handoff.sh --isolate --paths <changed files>` is the canonical gate. Audit-specific checks appear only when the router cannot infer them. Do not substitute bare smoke or broad suites during iteration.

Prefer existing gates over aspirational absolute metrics. The only absolute-zero target is a failing enforced boundary gate; elsewhere use evidence, explicit allowlists, runtime history, and per-change ratchets.

Each audit holds only its distinct scope, confirmation rules, and domain allowlists. Shared platform policy lives in `AGENTS.md`; architecture and testing facts live in the Platform documents.

## Ownership

| # | Owner audit | Concern |
|---|-------------|---------|
| 01 | [01_AppleNativeUIAudit.md](01_AppleNativeUIAudit.md) | Custom layout/typography → Apple/SwiftUI native |
| 02 | [02_MaintenanceSurfaceLocalityAudit.md](02_MaintenanceSurfaceLocalityAudit.md) | Authored maintenance mass, locality, guidance, verification, and context cost (retrospective) |
| 03 | [03_BehaviorHardeningAudit.md](03_BehaviorHardeningAudit.md) | Persistence / idempotency / swallowed errors |
| 04 | [04_BugHuntingAudit.md](04_BugHuntingAudit.md) | Opportunistic defect hunt |
| 06 | [06_DeadParallelCeremonialSurfaceAudit.md](06_DeadParallelCeremonialSurfaceAudit.md) | Dead, parallel/compatibility, and ceremonial authored surface |
| 07 | [07_DocumentationStalenessAudit.md](07_DocumentationStalenessAudit.md) | Doc drift |
| 09 | [09_DuplicateFeatureSurfaceAudit.md](09_DuplicateFeatureSurfaceAudit.md) | Copy-paste feature screens / shells |
| 10 | [10_E2ETestQualityAudit.md](10_E2ETestQualityAudit.md) | UI / smoke / exhaustive test quality |
| 12 | [12_SideEffectSurfaceAudit.md](12_SideEffectSurfaceAudit.md) | RNG / I/O seams |
| 13 | [13_StateGravityOwnershipAudit.md](13_StateGravityOwnershipAudit.md) | Misplaced logic in AppState / hubs / mega-views |
| 14 | [14_SwiftConcurrencyDataRaceAudit.md](14_SwiftConcurrencyDataRaceAudit.md) | Concurrency / Sendable |
| 15 | [15_TypeSafetyAudit.md](15_TypeSafetyAudit.md) | Force casts / unwraps / typing escapes |
| 16 | [16_UIInteractionFeedbackAudit.md](16_UIInteractionFeedbackAudit.md) | UI interaction / a11y / HIG |
| 17 | [17_UnitTestAudit.md](17_UnitTestAudit.md) | Unit/package test value, runtime, redundancy, fixture sprawl, and tier ownership |
| — | [PerformanceInvestigationPlaybook.md](../Platform/PerformanceInvestigationPlaybook.md) | Device-led performance investigation |

Ownership determines where a finding is reported and deduplicated. It does not require leaving necessary callers, tests, configuration, docs, or adjacent symptoms unchanged when they belong to the same root-cause remedy.

### Confusable pairs

This table is the canonical routing for commonly confused hits. Audit guides keep at most their two or three closest neighbors and defer the rest here; one problem produces one finding under one owner.

| If the hit is… | Owner |
|----------------|-------|
| Zero live consumers, reachable twin/shim, or single-path ceremony in the correct owner | [06_DeadParallelCeremonialSurfaceAudit.md](06_DeadParallelCeremonialSurfaceAudit.md) |
| Wrong semantic owner, with or without a leftover twin | [13_StateGravityOwnershipAudit.md](13_StateGravityOwnershipAudit.md) (move, then delete the old path) |
| Large/mixed-jobs surface or recurring change/context fan-out | [02_MaintenanceSurfaceLocalityAudit.md](02_MaintenanceSurfaceLocalityAudit.md) |
| Copy-paste product screens or repeated view scaffolding across 3+ files | [09_DuplicateFeatureSurfaceAudit.md](09_DuplicateFeatureSurfaceAudit.md) (including repeated grid scaffolding spotted during AppleNativeUI passes) |
| Raw layout/typography literals without a structural twin | [01_AppleNativeUIAudit.md](01_AppleNativeUIAudit.md) |
| Duplicate, weak, or over-expanded test coverage | [17_UnitTestAudit.md](17_UnitTestAudit.md) (unit/package) or [10_E2ETestQualityAudit.md](10_E2ETestQualityAudit.md) (UI tiers) |
| Silent persistence/transition failure without ownership drift | [03_BehaviorHardeningAudit.md](03_BehaviorHardeningAudit.md) |
| Effect primitive outside its allowlisted seam | [12_SideEffectSurfaceAudit.md](12_SideEffectSurfaceAudit.md) |

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
