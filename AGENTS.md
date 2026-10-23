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
- Use one isolated worktree and `codex/` task branch per implementation chat, based on committed local `main` unless instructed otherwise. Reuse that chat's suitable worktree; do not inspect other chats to decide whether isolation is needed. Keep the primary checkout on `main` for locked integration only. [Isolated chat workflow](Docs/Platform/Release.md#isolated-chat-workflow) owns commands, locking, and recovery.
- Implementation tasks authorize task-scoped commits and verified local integration into `main`, unless the user restricts the task. Landing retains the checkout; run `node Scripts/agent-worktree.mjs cleanup` after finishing the task and preserving deliverables. Pushes, PRs, publication, and unrelated changes need separate authorization. [Release](Docs/Platform/Release.md#isolated-chat-workflow) owns recovery; [TestFlight](Docs/Platform/Release.md#local-testflight-deployment) owns deployment.
- Edit authored inputs, never generated code/resources, `.DerivedData/`, `.tools/`, or the Xcode project. CI checks generation freshness; `./Scripts/generate.sh` explicitly regenerates.
- Never kill foreign Xcode/Simulator processes. [Verification](Docs/Platform/Verification.md) owns isolation and diagnostics.

## Product constraints

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
3. Implement and run `./Scripts/handoff.sh --quiet` in the task checkout. It derives task scope from `main`, runs scoped static checks and directly affected package tests serially, and compiles the app when needed. `--dry-run` previews; `--paths <files...>` narrows iteration checks.
4. Review the full task diff, commit task files, then run `node Scripts/agent-worktree.mjs integrate`. If main advanced, review the combined changes and refresh affected verification before retrying. If current main was already reviewed, pass `--reviewed-main <commit>`; a later advance still stops landing.
5. Report the local result and remaining verification, then clean up the task checkout when no further work needs it.

`--base <ref>` selects a user-specified base for briefing and handoff; `--base main`
includes task commits plus dirty files, deletions and both rename endpoints.
`--working-tree` selects dirty files only. Never narrow the final task scope to
hide failures. The briefing is the only required retrieval tool; other navigation
helpers are optional compatibility utilities. Index pages are lookup aids.
Create an [execution plan](Docs/Plans/README.md) only when durable resumption needs it.

## Choose the change

Player-facing text changes complete [localization](Docs/Platform/Localization.md#agent-workflow)
in the same task. `python3 Scripts/localization.py job` prepares resumable translation
and independent-review tasks; the agent completes them and runs the printed finish command.
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
- Handoff selects bounded local checks automatically. Explicit package/UI selectors remain available; `--route static` runs cheap checks only. Broad qualification and generation freshness stay hosted. [Verification](Docs/Platform/Verification.md#confidence-ladder) owns selection and resource limits.
- Player-facing layout, copy, artwork and motion changes require inspection of the final shipping UI under the [visual completion gate](Docs/Platform/Verification.md#visual-completion-gate). Compilation and test success alone do not establish visual quality.
- Integration holds the shared lock, preserves dirty work, and runs a final static check with plan closure. It retains the checkout. Evidence is saved automatically; put visual artifacts in `.DerivedData/Deliverables/`.
- Report what passed and exact blockers/skips. **Locally integrated; hosted verification pending** is a valid local handoff, not a claim of full qualification. Follow hosted checks after a separately authorized push; do not require hosted results before that push. Cleanup preserves deliverables outside the task checkout and retains the branch.

## Maintain guidance

Update canonical policy owners with behavior changes; follow [documentation editing](Docs/README.md#editing-guidance).
Load [knowledge](.agents/knowledge/index.md) only for its concern. Record misleading
guidance or recurring friction in [.agents/FRICTION_LOG.md](.agents/FRICTION_LOG.md);
when resolved, move lasting guidance to its owner and delete the entry. Keep
one-off failures in session history.
