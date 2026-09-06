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

- Inspect `git status --short` before editing and each dirty file's diff before touching it. Preserve in-flight work with surgical edits; use an isolated worktree when ownership is unclear.
- Never discard, overwrite, or stash unrelated work, or run destructive Git commands against a dirty tree. If the safety shim creates a backup before blocking, inspect it and current state before restoration.
- Keep the primary checkout on `main`; do not branch there or open pull requests. Create isolated work with `node Scripts/agent-worktree.mjs create --task <slug>` under `.worktrees/` on `agent/<slug>`.
- Commit/push only when requested, following [Release.md](Docs/Platform/Release.md). Include only requested/adopted changes; stage hunks for mixed files. Hosted CI follows a push to `main`, not a prerequisite for it.
- Edit authored inputs, never generated code/resources, `.DerivedData/`, `.tools/`, or the Xcode project. Normal build/handoff handles generation freshness; use `./Scripts/generate.sh` for explicit regeneration.
- Never kill foreign Xcode/Simulator processes. Follow [Verification.md](Docs/Platform/Verification.md) for isolation and diagnostics.

## Product constraints

- Use the checked-in deployment target and first-party SwiftUI; no legacy compatibility or UIKit feature chrome. Extend existing measured UIKit feedback only through its package guide.
- Do not remove launch/imminent artwork pins, switch first-screen art to on-demand `Image(name)`, or lower artwork memory budgets without product approval. [Performance playbook](Docs/Platform/PerformanceInvestigationPlaybook.md) owns budgets; `check-artwork-budget.sh` enforces them.
- Preserve or migrate saves, serialized identifiers, manifests, and live schemas unless the consumer window is proven closed or a break is approved. Source/API compatibility needs a confirmed current consumer.
- No explanatory Swift comments or temporary debug output. [doc-budget](.agents/skills/doc-budget/SKILL.md) and `check-comment-ban.sh` own permitted directives and exceptions.

## Route and read

Run `./Scripts/agent-context.sh --agent --paths <file...>` once likely touched paths
are known. Read its required guides/cards; load skills when their triggers apply.
Reuse unchanged guidance already present in context; reread when changed or no
longer available. Reroute when scope crosses owners and read newly applicable
material. Use `--working-tree` only for intentional whole-tree work.

Search authored owner paths with `rg` and bounded reads. Load linked material only
for its concern; generated catalogs/logs need targeted lookups. See
[context reading examples](Docs/AgentContext/README.md). Use an execution plan only
for durable coordination/resumption; [Plans](Docs/Plans/README.md) owns lifecycle.

## Choose the change

- Fix the owning module's root cause. Prefer deletion, reuse, or simplification; larger changes must remove the complete cause or replaced path.
- Keep types/files cohesive. Share abstractions for confirmed repeated behavior or enforced boundaries, not predicted reuse. Avoid speculative extension points, compatibility layers, or defensive paths for impossible states.
- Prefer existing dependencies. New ones need material simplification and checked maintenance, license, platform, and toolchain fit.
- Delete replaced implementations and redundant tests unless current compatibility requires parallel paths. Production/test surface is a budget: explain advisory `change-budget.sh` warnings and the simpler alternative rejected; do not compress code to satisfy counts.

Adopt encountered reproducible defects, gate failures, documentation drift, or
bounded debt only within scope when evidence, intended behavior, and ownership are
clear and the complete fix is reversible with targeted verification. No speculative
sweeps. Ambiguous product choices, migrations, dependencies, architectural
boundaries, or broad rewrites require a proposal; continue independent authorized
work. Unrelated dirty work is never permission to overwrite it.

## Verify and hand off

- Use [Testing.md](Docs/Platform/Testing.md) for consequential coverage in the cheapest owner; new tests are not automatic.
- Run `./Scripts/handoff.sh --isolate --paths <file...>` for the union of requested and adopted paths, including deletions. Add `--final` when closing an execution plan. [Verification.md](Docs/Platform/Verification.md) owns gates, simulator limits, and failures.
- Review the final diff for scope and generated consistency. Report results, verification, adopted fixes separately, and exact blockers/skips. Do not claim verified completion with unresolved required checks.

## Maintain guidance

Update canonical policy owners with behavior changes; link rather than duplicate.
Load [knowledge](.agents/knowledge/index.md) only for its concern. Record misleading
guidance or recurring friction in [.agents/FRICTION_LOG.md](.agents/FRICTION_LOG.md),
with a fix link when resolved. Keep one-off failures in session history.
