# Trinket agent guide

Portrait-first iOS fantasy turn-based card combat. SwiftUI + SPM packages under `Packages/`; Xcode project generated from `project.yml`. Checked-in configuration owns toolchain versions; setup and commands live in [`Scripts/README.md`](Scripts/README.md).

This file owns repository-wide agent behavior. Nested `AGENTS.md` files add local constraints. Use the [documentation map](Docs/README.md) to find the owner of a policy; link to that owner instead of repeating it.

## Communication

Write for someone who knows Trinket as a game, not its implementation. Use plain language and established player-facing names. Include code-level detail when requested or needed to explain a decision, risk, or blocker. State assumptions that materially affect the result; distinguish verified behavior from inference.

## Protect the workspace

- Inspect `git status --short` before editing. Existing changes are in-flight user work. Inspect a dirty file's diff before touching it; make surgical edits that preserve its intent. If ownership cannot be distinguished safely, use an isolated worktree or report the conflict.
- Never discard, overwrite, or stash unrelated work to simplify a task or make a check pass. Do not run destructive Git commands against a dirty tree. The Git safety shim can itself move work into a stash before blocking; it is a fallback, not permission to attempt the command. If triggered, inspect the backup and current state before restoring anything.
- Keep the primary checkout on `main`; do not create or switch branches there or open pull requests. Use `node Scripts/agent-worktree.mjs create --task <slug>` for isolated work under `.worktrees/` on `agent/<slug>`. Worktree setup is documented in [`Scripts/README.md`](Scripts/README.md).
- Commit and push only when explicitly requested, following [`Release.md`](Docs/Platform/Release.md). Include only requested work and explicitly adopted fixes; stage individual hunks when a file also contains unrelated changes. Hosted CI runs after a push to `main`; its status is not a prerequisite for that push.
- Never hand-edit generated code, processed assets/resources, `.DerivedData/`, `.tools/`, or the Xcode project. Edit authored inputs; use `./Scripts/generate.sh` when regeneration is needed. Normal build and handoff routes handle generation freshness.
- Never kill foreign Xcode or Simulator processes. Use the isolation and diagnostics procedures linked from [Verification.md](Docs/Platform/Verification.md).

## Product and platform constraints

Nested guides may tighten these constraints, not relax them.

- Use the checked-in deployment target and first-party SwiftUI APIs. Do not add legacy-platform compatibility or UIKit bridges for feature chrome. Existing measured UIKit feedback infrastructure is an owned exception; extend it only through its package guide.
- Do not drop launch or imminent artwork pins, switch first-screen art to on-demand `Image(name)`, or lower artwork memory budgets without product approval. See [artwork budgets](Docs/Platform/PerformanceInvestigationPlaybook.md) and `check-artwork-budget.sh`.
- Persisted saves, serialized identifiers, manifests, and live schemas are product data: preserve or migrate them unless the consumer window is proven closed or an intentional break is approved. Source/API compatibility is required only for a confirmed current consumer.
- Do not author explanatory Swift comments or leave temporary debug output. Use only checker-approved directives and narrow exception annotations; `check-comment-ban.sh` and the [doc-budget skill](.agents/skills/doc-budget/SKILL.md) own the accepted forms.

## Route the task

Once likely touched paths are known, run `./Scripts/agent-context.sh --agent --paths <file...>`. Read the listed root/nested guides and required context cards; load skills when their triggers apply. Rerun routing when scope crosses into another owner. Use `--working-tree` only for an intentional whole-tree task.

Read linked material only when it concerns the task. Search authored owner paths with `rg` and bounded reads; generated catalogs and logs are targeted lookups. Follow the [documentation map's conflict rules](Docs/README.md#policy-precedence) when guidance disagrees.

Use a checked-in execution plan when work needs durable coordination or resumption, not for every edit. [Plans](Docs/Plans/README.md) owns location, metadata, and closure requirements.

## Choose the change

- Solve the root cause in the module that owns the behavior. Prefer deletion, reuse, or local simplification before a new abstraction. A larger change is justified when it removes the complete cause or a replaced path; size alone is neither a virtue nor a defect.
- Keep files and types cohesive. Introduce a shared abstraction for confirmed repeated behavior or an enforced boundary, not predicted future reuse. Do not add extension points, compatibility layers, or defensive paths for states excluded by an enforced invariant.
- Prefer an established repository dependency over a custom implementation. A new dependency needs a material complexity reduction and a checked maintenance, license, platform, and toolchain fit.
- Remove replaced implementations and redundant tests. Keep parallel paths only when a current compatibility requirement needs them.
- Treat production and test surface as budgets. A `change-budget.sh` warning is advisory: explain the necessity and simpler alternative rejected; do not compress code to satisfy a count.

### Encountered fixes

The request defines initial scope. Adopt reproducible defects, gate failures, documentation drift, or bounded technical debt encountered in that scope when evidence establishes the problem, the intended behavior and owner are clear, and the complete remedy is reversible and has targeted verification. This does not authorize speculative repository sweeps.

For each adopted fix, include its paths in routing and final verification and report it separately. Propose work outside existing authorization when it requires ambiguous product behavior, a persisted-data migration, a new dependency or architectural boundary, or a broad rewrite. Continue independent authorized work while that decision is pending. A failure caused by unrelated in-flight work does not authorize overwriting that work.

## Verify and hand off

- Follow [Testing.md](Docs/Platform/Testing.md) to choose consequential coverage in the cheapest existing owner. Verification does not automatically require a new test.
- Run `./Scripts/handoff.sh --isolate --paths <file...>` before handoff using the final union of requested and adopted paths, including deleted paths. Add `--final` when closing work that used an execution plan. [Verification.md](Docs/Platform/Verification.md) owns gate selection, local simulator limits, and failure handling.
- Review the final diff for scope, accidental changes, and generated-output consistency. A green gate proves only the checks it ran; report skipped or unavailable required checks and their exact blockers. Do not claim verified completion while a required check is unresolved.
- Briefly report the result, verification status, adopted fixes, and remaining limitations. Commit/push status matters only when requested.

## Maintain guidance

Keep durable rules with their canonical owner and update them with behavior changes. Skills live in [`.agents/skills/`](.agents/skills/); load [knowledge](.agents/knowledge/index.md) only when its concern applies. One-off failures stay in session history. Record misleading guidance or recurring friction in [`.agents/FRICTION_LOG.md`](.agents/FRICTION_LOG.md), with a fix link when resolved. Do not turn each incident into another standing rule.
