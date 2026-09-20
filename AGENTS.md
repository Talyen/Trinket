# Trinket agent guide

Portrait-first iOS fantasy turn-based card combat. SwiftUI + SPM under `Packages/`;
Xcode project generated from `project.yml`. Configuration pins toolchains.
[Scripts](Scripts/README.md) owns commands; nested `AGENTS.md` files add local
constraints; [Docs](Docs/README.md) owns policy precedence.

## Communication

Write for someone who knows Trinket as a game. Use player-facing names, explain
material decisions/risks/blockers, and distinguish verified behavior from inference.

## Protect the workspace

- Before editing, inspect scoped status with the router below and every overlapping dirty file's full diff. Preserve in-flight work with surgical edits; clarify unclear ownership. Use `git status --short` only for intentional whole-tree inspection.
- Never discard, overwrite, or stash unrelated work, or run destructive Git commands against a dirty tree.
- Work in the primary checkout on `main`; no routine worktrees, branches, or pull requests.
- Commit/push only when requested. Read [Release](Docs/Platform/Release.md#local-hooks-and-push-discipline) for staging and push rules; hosted CI follows a push, not a prerequisite for it. For TestFlight, read [deployment](Docs/Platform/Release.md#local-testflight-deployment) and use `./Scripts/testflight.sh` and its doctor.
- Edit authored inputs, never generated code/resources, `.DerivedData/`, `.tools/`, or the Xcode project. Build/handoff handles freshness; `./Scripts/generate.sh` explicitly regenerates.
- Never kill foreign Xcode/Simulator processes. [Verification](Docs/Platform/Verification.md) owns isolation and diagnostics.

## Product constraints

- Use first-party SwiftUI under the [platform policy](Docs/Platform/ApplePlatformReference.md#platform-support). The deployment target is a minimum, not an adoption ceiling; small supported-window availability checks are appropriate. Avoid legacy compatibility frameworks and UIKit feature chrome; existing measured UIKit feedback follows its package guide.
- Preserve launch/imminent artwork pins and first-screen prepared artwork; do not replace them with on-demand `Image(name)` or lower [artwork budgets](Docs/Platform/PerformanceInvestigationPlaybook.md) without product approval.
- Preserve or migrate saves, serialized identifiers, manifests, and live schemas unless the consumer window is proven closed or a break is approved. Source/API compatibility needs a confirmed current consumer.
- Prefer self-explanatory code and concise rationale/invariant comments; remove temporary debug output. Use [doc-budget](.agents/skills/doc-budget/SKILL.md) for checker directives or suppressions.

## Route and read

Start discovery with `python3 Scripts/agent-search.py --files <pattern> --scope <owner>`;
when the owner is unknown, use `--overview`. Asset filenames use `--mode assets --files`.
Scoped `rg --files` and content `rg` remain available after narrowing the surface.

Once paths are known, run `./Scripts/agent-context.sh --agent --status --paths <file...>`.
Read root/local safeguards and applicable routed ownership/behavior sections; load
skills by trigger. Reuse unchanged guidance already in context. Reroute across owners.
Use `--working-tree --allow-broad-scope` only for intentional whole-tree work.

Read sections with `python3 Scripts/agent-read.py 'path.md#heading'`; `--outline`
lists headings or Swift/Python declarations, `--symbol` reads a declaration, and
`--full` intentionally expands a large document. An outline is navigation, not a read.
Review all relevant pages of `python3 Scripts/agent-diff.py --paths <file...>` before
editing overlapping work. Follow relevant callers, tests, and configuration;
use targeted generated-catalog/log lookups. [Context examples](Docs/AgentContext/README.md)
own retrieval details. Create an [execution plan](Docs/Plans/README.md) only for
durable coordination/resumption.

## Choose the change

Fix the owning module's root cause with the simplest complete solution. Keep files
cohesive; reuse abstractions for confirmed repetition or enforced boundaries, not
predicted needs. Delete replaced code and redundant tests unless current compatibility
requires them. Prefer existing dependencies; new ones need material simplification
and checked maintenance, license, platform, and toolchain fit.

Adopt encountered defects, gate failures, documentation drift, or bounded debt only
within scope when reproducible, ownership/intended behavior are clear, and the full
fix is reversible with targeted verification. No speculative sweeps. Propose unresolved
product, migration, dependency, architecture, or broad-rewrite decisions; existing
session approval carries forward. Continue independent authorized work.

## Verify and hand off

Continue authorized work through implementation, relevant verification, and fixes
caused by the change without another approval checkpoint. Stop when complete or
blocked by a required decision or unavailable prerequisite.

- Follow [Testing](Docs/Platform/Testing.md#coverage-decision-new-and-changed-behavior) for consequential coverage and evidence-based retirement; test counts are not a goal.
- Run `./Scripts/handoff.sh --isolate --paths <file...>` for requested and adopted paths, including deletions. Add `--final` when closing an execution plan. [Verification](Docs/Platform/Verification.md) owns gates, limits, failure classification, and advisory change budgets.
- Review the final diff and generated consistency. Report results, verification, adopted fixes, and exact blockers/skips; distinguish task changes from pre-existing work. Do not claim verified completion with required checks unresolved.

## Maintain guidance

Update canonical policy owners with behavior changes; follow [documentation editing](Docs/README.md#editing-guidance).
Load [knowledge](.agents/knowledge/index.md) only for its concern. Record misleading
guidance or recurring friction in [.agents/FRICTION_LOG.md](.agents/FRICTION_LOG.md)
with a fix link when resolved; keep one-off failures in session history.
