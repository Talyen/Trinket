# Trinket agent guide

Portrait-first iOS fantasy turn-based card combat. SwiftUI + SPM packages under `Packages/`; Xcode project generated from `project.yml` (`./Scripts/generate.sh`). Requires Xcode 26+ — see toolchain ladder in [`Scripts/README.md`](Scripts/README.md).

This file is the router + universal constraints. Nested `AGENTS.md` add local hard stops; AgentContext cards and Platform docs own domain behavior, rationale, and exact commands.

Active skills live in [`.agents/skills/`](.agents/skills/); durable lessons in [`.agents/knowledge/`](.agents/knowledge/) (searchable, not auto-loaded — see [knowledge/index.md](.agents/knowledge/index.md)). Load knowledge only when the task touches its concern or a skill’s PURPOSE points there. One-off failures stay in session history.

## Communication

Write for a collaborator who knows Trinket as a game, not the file tree.

- **Lead with meaning in game terms.** First sentence is what is true / what changed for the player.
- **Prefer product / design / user language.** Game terminology (“enemies pick a new target,” “Homestead build,” “Collection detail,” “hand,” “shop”) is always welcome and encouraged.
- **Avoid strictly technical / code / engineering language by default.** Don’t lean on file paths, line numbers, function/method/class names, code blocks, diffs, package names, or script/gate names (`handoff.sh`, `check-docs`, `isolate`, `ci-gate`) in messages to the user. If technical detail helps, keep it brief and after the product summary — and only when you asked for depth.
- **Keep the work in the work.** Gates, budgets, generation, and diagnostics belong in the diff/logs; the chat summarizes in product terms.

## Guardrails

- These rules apply repository-wide. A nested `AGENTS.md` may add or tighten path-specific rules, but it may not relax this root Guardrails section.
- Preserve existing work. Do not clean, revert, or overwrite unrelated changes, and never stage or commit them.
- Keep work within the requested scope.
- Treat checked-in project configuration as the toolchain source of truth.
- Do not add legacy-platform compatibility or UIKit bridges when current SwiftUI provides a first-party solution.
- Never hand-edit generated code, processed assets/resources, `.DerivedData/`, `.tools/`, or the Xcode project. Edit authored inputs and run `./Scripts/generate.sh`.
- Do not drop launch or imminent artwork pins, switch first-screen art to on-demand `Image(name)`, or lower artwork memory budgets (`PreparedArtworkCache` / `NSCache.totalCostLimit`) without product approval. Enforced by `check-artwork-budget.sh`; see [PerformanceInvestigationPlaybook](Docs/Platform/PerformanceInvestigationPlaybook.md) and [`PreparedArtworkCache`](Packages/TrinketFeatureSupport/Sources/TrinketFeatureSupport/PreparedArtworkCache.swift).
- Keep the primary checkout on `main`. Do not create or switch branches, and do not open pull requests. Detached worktrees created by `./Scripts/agent-worktree.sh` are allowed for parallel verification. Land work by committing and pushing directly to `main` only when explicitly requested. For requested commit or release work, read [`Docs/Platform/Release.md`](Docs/Platform/Release.md).

## Task routing

Touched areas must respect their nested guides and AgentContext cards. Run `./Scripts/agent-context.sh --agent --paths <file...>` once the task's touched paths are known — it is the catalog for discovering path-specific guidance, skills, and verification plans, not a prerequisite ritual before thinking. Always use explicit `--paths`; use `--working-tree` only when whole-tree is intentional. Follow the briefing's required read contract and applicable skill routing. Rerun it when the task crosses into another area.

## Change discipline

- Deliver the most pragmatic architectural solution that fully satisfies the request — prefer the cleanest long-term shape over the narrowest diff. A larger, well-owned change that removes the root cause is preferred over a smaller workaround or local patch that leaves structural debt. Avoid speculative extension points, compatibility paths, or defensive layers for states already excluded by an enforced invariant. Adjacent cleanup is allowed when it is part of the pragmatic shape and improves the long-term owner; unrelated cleanup outside the chosen shape remains out of scope.
- Do not preserve source or API compatibility unless it is an explicit current requirement. Persisted saves, serialized identifiers, manifests, and live schemas are product data: preserve or migrate them unless the consumer window is proven closed or an intentional break is approved. Choose the simplest pragmatic implementation that fully satisfies the behavior the product needs now, judged by long-term maintainability and ownership fit — not by line count.
- Prefer an established dependency already used by the repository over a custom implementation. Add a new external dependency only when it materially reduces complexity and its maintenance, license, platform, and toolchain fit have been checked.
- Prefer the most pragmatic surface, ordered as delete → reuse → simplify locally → parameterize a confirmed duplicate → add an abstraction. Choose the step that best fits the long-term ownership and removes the root cause, not automatically the shortest step; a larger step that eliminates the defect class is preferred over a narrower local patch.
- Extend the module that already owns the behavior before adding a file, type, protocol, manager, helper, wrapper, or configuration object. A generic abstraction needs at least three current uses or an enforced architectural boundary; predicted future reuse is insufficient.
- Refactors remove the replaced path. Do not leave forwarding wrappers, parallel implementations, or duplicate tests unless compatibility explicitly requires them.
- Do not author Swift comments or leave temporary debug output. Code clarity and tests own intent; comment hygiene is enforced by `check-comment-ban.sh`.
- Treat authored production and test surface as budgets. Unusual growth is advisory, not a license to compress code: report the necessity and the simpler alternative rejected when `./Scripts/change-budget.sh` warns.

## Test and verification discipline

- Verification does not imply authoring a test. Follow [`Docs/Platform/Testing.md`](Docs/Platform/Testing.md) to place consequential coverage in the cheapest existing semantic owner; that guide owns persistence reload semantics and the UI keep/drop rubric.
- Full smoke and exhaustive UI are CI-owned post-push gates. Local simulator work is limited to routed targeted smoke classes or single-target UI debugging; reserve full local UI runs for release-time deploy verification (`test-deploy.sh`).
- Before handoff, run path-scoped verification with `--isolate`. `./Scripts/handoff.sh --isolate --paths <file...>` is the canonical gate; add `--final` when closing a task that used an execution plan. Do not claim completion unless the routed gate passes; if a required step is unavailable, report the exact blocker or skip. Never kill foreign Xcode or Simulator processes; concurrency, worktree, lock, and diagnostics details live in [`Docs/AgentContext/ci-and-project-generation.md`](Docs/AgentContext/ci-and-project-generation.md) and [`Docs/AgentContext/ci-diagnostics.md`](Docs/AgentContext/ci-diagnostics.md).
- At handoff, report what changed, what you checked, and what you intentionally left alone — in the same product voice as Communication, readable without opening the diff. Example: “Enemies now pick a new target if the current one dies mid-turn. Checked that battles still play and the shop still opens.” Not: “Refactored `BattleTurnEngine.swift:42` targeting resolution. Ran `handoff.sh --isolate --paths …`.” Include pass/fail and skips in product terms; omit file paths, line numbers, and script names unless you asked for them. Include any change-budget justification in the same voice.

## Commit and push

- Commits include only task-related authored and generated files and must pass repository hooks. Path-scoped verification should be green before commit.
- Push only when explicitly requested. Generation completeness against HEAD (`./Scripts/agent-push-gate.sh`) must be green before push; if generation changes files, review them, include them, and ensure the gate is clean. Exact commands: [`Docs/Platform/Release.md`](Docs/Platform/Release.md).
- Hosted CI runs after a push to `main`. Do **not** require `tests / CI OK` as a GitHub **push** gate; that status is produced by the post-push run.
