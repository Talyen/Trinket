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

- Before editing, inspect scoped status with the briefing below and every overlapping dirty file's full diff. Preserve in-flight work with surgical edits; clarify unclear ownership. Use `git status --short` only for intentional whole-tree inspection.
- Never discard, overwrite, or stash unrelated work, or run destructive Git commands against a dirty tree.
- Use one isolated worktree and `codex/` task branch per implementation chat, based on committed local `main` unless instructed otherwise. Reuse that chat's suitable worktree; do not inspect other chats to decide whether isolation is needed. Keep the primary checkout on `main` for locked integration only. [Isolated chat workflow](Docs/Platform/Release.md#isolated-chat-workflow) owns commands, locking, and recovery.
- Implementation tasks authorize task-scoped commits and verified local integration into `main`, unless the user restricts the task. Verified integration automatically deletes and unregisters only the invoking task worktree, including ignored files and build outputs, while retaining its branch. Use `agent-worktree.mjs integrate --keep-worktree` for intermediate landings while requested work or a preview still needs it. Pushes, PRs, publication, other destructive cleanup, and unrelated changes require separate authorization. Read [Release](Docs/Platform/Release.md#local-hooks-and-push-discipline) for staging and push rules; hosted CI runs after a push and is not a prerequisite for it. For TestFlight, read [deployment](Docs/Platform/Release.md#local-testflight-deployment) and use `./Scripts/testflight.sh` and its doctor.
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

Use ordinary scoped `rg`, file reads, and `git diff` for discovery and review.
Before editing intended files, run
`python3 Scripts/agent-brief.py --status --read --paths <files...>` once for
applicable safeguards and initial contracts. Reuse unchanged guidance already in
context; read the linked sections relevant to the behavior being changed.

As the task grows, `--base main` derives scope from task commits plus dirty files,
including deletions and both rename endpoints. Use the user-specified base when
different. Rerun briefing when entering another owner. `--paths` remains useful for
focused work; `--working-tree` is an intentional whole-tree dirty-file view.

Concern shortcuts (`--task shop`) and the specialized search/read/investigate/diff
helpers are optional. [Retrieval](Docs/AgentContext/Retrieval.md) documents them;
they do not impose a required sequence. Read every relevant overlapping dirty diff
before editing and follow callers, tests, and configuration as needed. Create an
[execution plan](Docs/Plans/README.md) only for durable coordination/resumption.

## Choose the change

Player-facing text changes include localization in the same task. Follow
[Localization](Docs/Platform/Localization.md): run `python3 Scripts/localization.py plan`,
translate the affected queue in every configured language, perform a separate AI
review pass, apply the reviewed response, and rerun `check`. Never stamp review
records without the review or copy English into other locales to clear a gate.
The working agent performs translation; hooks, builds and CI never call AI.

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
- Keep routine local verification resource-light: no automatic Swift compilation, simulator/UI/performance tests, or broad generation. CI owns those checks; [Verification](Docs/Platform/Verification.md#local-simulator-budget) owns deliberate exceptions and local play.
- Run `./Scripts/handoff.sh --isolate --quiet --base main` for the full task (or its user-specified base); use `--paths <files...>` for focused checks. Add `--final` when closing an execution plan. [Verification](Docs/Platform/Verification.md) owns gates, limits, failure classification, and advisory change budgets.
- Review the final diff and generated consistency. Report results, verification, adopted fixes, and exact blockers/skips; distinguish task changes from pre-existing work. A local handoff proves only its lightweight checks; report CI-owned checks as pending until hosted evidence confirms them.

## Maintain guidance

Update canonical policy owners with behavior changes; follow [documentation editing](Docs/README.md#editing-guidance).
Load [knowledge](.agents/knowledge/index.md) only for its concern. Record misleading
guidance or recurring friction in [.agents/FRICTION_LOG.md](.agents/FRICTION_LOG.md);
when resolved, move lasting guidance to its owner and delete the entry. Keep
one-off failures in session history.
