# Trinket agent guide

Portrait-first iOS fantasy turn-based card combat. SwiftUI + SPM under `Packages/`;
Xcode project generated from `project.yml`. Configuration pins toolchains;
[Scripts](Scripts/README.md) owns commands. Nested `AGENTS.md` files add local
constraints. [Documentation map](Docs/README.md) owns policy precedence.

## Communication

Write for someone who knows Trinket as a game. Use player-facing names; include
implementation detail when needed for a decision, risk, or blocker. Distinguish
verified behavior from inference and state material assumptions.

## Protect the workspace

- Inspect scoped Git status with the routing command below before editing, then each overlapping dirty file's full diff. Use `git status --short` for intentional whole-tree inspection. Preserve in-flight work with surgical edits; clarify ownership before editing overlapping changes when it is unclear.
- Never discard, overwrite, or stash unrelated work, or run destructive Git commands against a dirty tree. The safety shim refuses these commands without stashing working files.
- Work directly in the primary checkout on `main` by default; do not create worktrees for routine tasks, branch there, or open pull requests.
- Commit/push only when requested, following [Release.md](Docs/Platform/Release.md). Include only requested/adopted changes; stage hunks for mixed files. Hosted CI follows a push to `main`, not a prerequisite for it.
- For TestFlight deployment, use `./Scripts/testflight.sh`; [Release.md](Docs/Platform/Release.md#local-testflight-deployment) owns setup, recovery, and readiness. Use its doctor before improvising Xcode or App Store Connect steps.
- Edit authored inputs, never generated code/resources, `.DerivedData/`, `.tools/`, or the Xcode project. Normal build/handoff handles generation freshness; use `./Scripts/generate.sh` for explicit regeneration.
- Never kill foreign Xcode/Simulator processes. Follow [Verification.md](Docs/Platform/Verification.md) for isolation and diagnostics.

## Product constraints

- Use first-party SwiftUI and the [platform support policy](Docs/Platform/ApplePlatformReference.md#platform-support); the deployment target is a minimum, not an adoption ceiling. Small availability checks within the supported window are appropriate; avoid legacy compatibility frameworks and UIKit feature chrome. Extend existing measured UIKit feedback only through its package guide.
- Do not remove launch/imminent artwork pins, switch first-screen art to on-demand `Image(name)`, or lower artwork memory budgets without product approval. [Performance playbook](Docs/Platform/PerformanceInvestigationPlaybook.md) owns budgets; `check-artwork-budget.sh` enforces them.
- Preserve or migrate saves, serialized identifiers, manifests, and live schemas unless the consumer window is proven closed or a break is approved. Source/API compatibility needs a confirmed current consumer.
- Prefer self-explanatory code. Add concise comments for non-obvious rationale, invariants, or platform limitations; avoid narrating the implementation. Remove temporary debug output. [doc-budget](.agents/skills/doc-budget/SKILL.md) covers checker directives and suppression reasons.

## Route and read

Run `./Scripts/agent-context.sh --agent --status --paths <file...>` once likely touched paths
are known. Read root/local safeguards and applicable ownership constraints; use the
routed cards to find relevant behavior contracts. Load skills when their triggers apply.
Reuse unchanged guidance already present in context; reread when changed or no
longer available. Reroute when scope crosses owners and read newly applicable
material. Use `--working-tree --allow-broad-scope` only for intentional whole-tree work.

For unknown owners or broad concepts, use filename-only `rg -l`/`rg --files` or
`python3 Scripts/agent-search.py <pattern> --scope <owner>`. Inspect matching
content only after narrowing paths.
Follow relevant callers, tests, and configuration across owners. Load linked material only
for its concern; generated catalogs/logs need targeted lookups. See
[context reading examples](Docs/AgentContext/README.md). Use an execution plan only
for durable coordination/resumption; [Plans](Docs/Plans/README.md) owns lifecycle.

## Choose the change

- Fix the owning module's root cause with the simplest complete solution. Reuse or delete when that improves clarity; additional code is appropriate for correctness, coherent ownership, or measured performance.
- Keep types/files cohesive. Share abstractions for confirmed repeated behavior or enforced boundaries, not predicted reuse. Avoid speculative extension points, compatibility layers, or defensive paths for impossible states.
- Prefer existing dependencies. New ones need material simplification and checked maintenance, license, platform, and toolchain fit.
- Delete replaced implementations and redundant tests unless current compatibility requires parallel paths. `change-budget.sh` counts are investigation signals, not targets or mandatory justification triggers; distinguish task changes from pre-existing work. Explain material tradeoffs, not every threshold crossing.

Adopt encountered reproducible defects, gate failures, documentation drift, or
bounded debt only within scope when evidence, intended behavior, and ownership are
clear and the complete fix is reversible with targeted verification. No speculative
sweeps. Propose unresolved decisions about product choices, migrations,
dependencies, architectural boundaries, or broad rewrites; existing session
approval carries forward. Continue independent authorized work. Unrelated dirty
work is never permission to overwrite it.

## Verify and hand off

Continue authorized work through implementation, relevant verification, and fixes
for failures caused by the change without another approval checkpoint. Stop when
complete or blocked by a required decision or unavailable prerequisite; apply the
encountered-fix rules above to other failures.

- Choose tests for consequential confidence under [Testing.md](Docs/Platform/Testing.md#coverage-decision-new-and-changed-behavior). Consolidate or retire coverage made redundant within scope when evidence justifies it; test counts are not a goal and evidence-based retirement needs no separate approval.
- Run `./Scripts/handoff.sh --isolate --paths <file...>` for the union of requested and adopted paths, including deletions. Add `--final` when closing an execution plan. [Verification.md](Docs/Platform/Verification.md) owns gates, simulator limits, and failures.
- Review the final diff for scope and generated consistency. Report results, verification, adopted fixes separately, and exact blockers/skips. Do not claim verified completion with unresolved required checks.

## Maintain guidance

Update canonical policy owners with behavior changes; link rather than duplicate.
Load [knowledge](.agents/knowledge/index.md) only for its concern. Record misleading
guidance or recurring friction in [.agents/FRICTION_LOG.md](.agents/FRICTION_LOG.md),
with a fix link when resolved. Keep one-off failures in session history.
