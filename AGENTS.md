# Trinket agent guide

Portrait-first iOS fantasy turn-based card combat. SwiftUI + SPM under `Packages/`;
Xcode project generated from `project.yml`; [toolchain ladder](Scripts/Reference.md#toolchain-ladder) owns Xcode selection.
[Scripts](Scripts/README.md) owns commands; nested `AGENTS.md` files add local
constraints; [Docs](Docs/README.md) owns policy precedence.

## Communication

Write for someone who knows Trinket as a game. Use player-facing names, explain
material decisions/risks/blockers, and distinguish verified behavior from inference.

Chats work independently. Task-relevant messaging is authorized only for a concrete
unresolved dependency or conflict that cannot be answered from the repository.
No startup announcements, ownership negotiations, progress/completion broadcasts,
acknowledgments, verification-window requests, or routine peer polling. Keep a
necessary exchange bounded; do not reply merely to acknowledge a message.
After completion, stop: do not message, poll, or wake completed chats unless the
user explicitly asks to resume them. Unsolicited routine messages require no reply
and do not reopen a task.

## Protect the workspace

- Read every overlapping dirty file's full diff before editing; preserve unrelated and unfinished work. The briefing below supplies scoped status.
- Never discard, overwrite, or stash unrelated work, or run destructive Git commands against a dirty tree.
- Use one isolated worktree and `codex/` task branch per implementation chat, based on committed local `main` unless instructed otherwise. Reuse that chat's suitable worktree; do not inspect other chats to decide whether isolation is needed. Keep the primary checkout on `main` for locked integration only. [Isolated chat workflow](Docs/Platform/Development.md#isolated-chat-workflow) owns commands, locking, and recovery.
- Implementation tasks authorize task-scoped commits and verified local integration into `main`, unless the user restricts the task. Landing retains the checkout; run `node Scripts/agent-worktree.mjs cleanup` after finishing the task and preserving deliverables. Pushes, PRs, and publication need explicit authorization. For Trinket, an authorized publication includes other reviewed, ready commits already on the branch being published; do not request separate approval solely because they originated in another task. Unrelated implementation changes still need authorization; preserve unfinished work and follow explicit publication restrictions. [Development](Docs/Platform/Development.md#isolated-chat-workflow) owns recovery; [TestFlight](Docs/Platform/Release.md#local-testflight-deployment) owns deployment.
- Edit authored inputs, never generated code/resources, `.DerivedData/`, `.tools/`, or the Xcode project. CI checks generation freshness; `./Scripts/generate.sh` explicitly regenerates.
- Never kill foreign Xcode/Simulator processes. [Verification](Docs/Platform/Verification.md) owns isolation and diagnostics.

## Product constraints

- Avoid taglines, avoid helper text, avoid secondary labels - if a screen needs them to make sense, fix the layout instead. [Design principles](Docs/Product/DesignPrinciples.md#clarity-through-layout) owns this UI/UX rule.
- Every supported player action needs prompt, perceptible feedback under [Design principles](Docs/Product/DesignPrinciples.md); existing visible responses count. Apply it to UI/UX and gameplay interaction changes.
- Use first-party SwiftUI under the [platform policy](Docs/Platform/ApplePlatformReference.md#platform-support). The deployment target is a minimum, not an adoption ceiling; small supported-window availability checks are appropriate. Avoid legacy compatibility frameworks and UIKit feature chrome; existing measured UIKit feedback follows its package guide.
- Preserve launch/imminent artwork pins and first-screen prepared artwork; do not replace them with on-demand `Image(name)` or lower [artwork budgets](Docs/Platform/PerformanceInvestigationPlaybook.md) without product approval.
- Author or generate artwork from the canonical action-anime templates in the [Artwork production guide](Docs/Product/ArtworkStyleGuide.md#prompt-construction).
- Preserve or migrate saves, serialized identifiers, manifests, and live schemas unless the consumer window is proven closed or a break is approved. Source/API compatibility needs a confirmed current consumer.
- Prefer self-explanatory code and concise rationale/invariant comments; remove temporary debug output. Use [doc-budget](.agents/skills/doc-budget/SKILL.md) for checker directives or suppressions.

## Route and read

The ordinary implementation loop is:

1. Create a task checkout: `node Scripts/agent-worktree.mjs create --task <slug>`.
2. Locate intended files with `rg`, then run `python3 Scripts/agent-brief.py --status --read --paths <files...>` before editing. Read the affected behavior contracts and inspect overlapping dirty diffs. Reuse unchanged guidance; rerun when entering another owner.
3. Implement and run `./Scripts/handoff.sh --quiet` for the complete task. Routine local verification is static; compilation, package tests, UI suites and performance runs belong to hosted CI. One task-related [single focused diagnostic](Docs/Platform/Verification.md#single-focused-local-diagnostic) is authorized without approval under its selector, worker and deadline limits. Other local compiled checks or heavy-local overrides require an express user request; bounded shipping-UI inspection follows the visual gate. [Verification](Docs/Platform/Verification.md#confidence-ladder) owns selection, previews, and iteration scope.
4. Review the full task diff, commit task files, then run `node Scripts/agent-worktree.mjs integrate`. If main advanced, review the combined changes and refresh affected verification before retrying. If current main was already reviewed, pass `--reviewed-main <commit>`; a later advance still stops landing.
5. Report the local result and remaining verification, then clean up the task checkout when no further work needs it.

Never narrow final task scope to hide failures. The briefing is the only required
retrieval tool; indexes and other navigation helpers are optional. Use the
[command reference](Scripts/Reference.md#development) for scope options.
Create an [execution plan](Docs/Plans/README.md) only when durable resumption needs it.

## Choose the change

Player-facing text changes complete [localization](Docs/Platform/Localization.md#agent-workflow)
in the same task. `python3 Scripts/localization.py run` coordinates resumable translation
and independent review; `job` remains available for manual coordination with another AI tool.
Retain every configured language and a separate actual AI review; never fabricate
review records or copy English to clear a gate. Hooks, builds and CI never call AI.

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

- Add tests only for consequential gaps in existing protection; use the three questions in [Testing](Docs/Platform/Testing.md#coverage-decision-new-and-changed-behavior). Verification does not require new test code.
- Use the [visual completion gate](Docs/Platform/Verification.md#visual-completion-gate) for presentation or UI interaction changes and clear readability risks. Content and copy changes within existing UI normally follow the static completion path; they do not automatically require a simulator run.
- Report the checks that ran and exact blockers/skips using [Verification's completion states](Docs/Platform/Verification.md#completion-states). Pending hosted checks do not block an otherwise complete local task or authorize a push.
- Save visual artifacts in `.DerivedData/Deliverables/`; [Development](Docs/Platform/Development.md#evidence-and-cleanup) owns evidence preservation and cleanup.

## Maintain guidance

Update canonical policy owners with behavior changes; follow [documentation editing](Docs/README.md#editing-guidance).
Load [knowledge](.agents/knowledge/index.md) only for its concern. Record misleading
guidance or recurring friction in [.agents/FRICTION_LOG.md](.agents/FRICTION_LOG.md);
when resolved, move lasting guidance to its owner and delete the entry. Keep
one-off failures in session history.
