# Trinket agent guide

Portrait-first iOS fantasy turn-based card combat. SwiftUI + SPM under `Packages/`;
Xcode project generated from `project.yml`; [toolchain ladder](Scripts/Reference.md#toolchain-ladder) owns Xcode selection.
[Scripts](Scripts/README.md) owns commands, nested `AGENTS.md` files add local constraints, and [Docs](Docs/README.md) owns policy precedence and documentation editing. Load [knowledge](.agents/knowledge/index.md) only for its concern, and log recurring guidance friction in [.agents/FRICTION_LOG.md](.agents/FRICTION_LOG.md).

## Workspace and workflow

- **Isolate implementation work**: Use one task worktree (`node Scripts/agent-worktree.mjs create --task <slug>`) and `codex/` branch per implementation chat; keep the primary checkout on `main` for locked integration (`integrate`). Never discard, overwrite, or stash unrelated work, or run destructive Git commands against a dirty tree. [Development](Docs/Platform/Development.md#isolated-chat-workflow) owns flags, locking, evidence preservation, and recovery.
- **Brief before editing**: Run `python3 Scripts/agent-brief.py --status --read --paths <files...>` to load scoped contracts and check overlapping dirty diffs.
- **Edit authored inputs only**: Never edit generated code/resources, `.DerivedData/`, `.tools/`, or the Xcode project; use `./Scripts/generate.sh` to regenerate. Never kill foreign Xcode/Simulator processes ([Verification](Docs/Platform/Verification.md)).
- **Static-first verification**: Run `./Scripts/handoff.sh --quiet` for the complete task. Routine local verification is static; compilation, package tests, UI suites, and performance runs belong to hosted CI. One task-related [single focused diagnostic](Docs/Platform/Verification.md#single-focused-local-diagnostic) is authorized without approval; other local compiled runs require an explicit user request. Visual inspection is optional unless requested ([Verification](Docs/Platform/Verification.md#visual-inspection)).
- **Authorization**: Implementation tasks authorize task-scoped commits, verified local integration into `main`, and pushing reviewed, ready changes unless restricted. Pull requests and release publication require explicit authorization ([Release](Docs/Platform/Release.md#local-testflight-deployment)).

## Product guardrails

- **Clarity through layout**: Avoid taglines, helper text, and secondary labels; fix the layout instead ([Design principles](Docs/Product/DesignPrinciples.md#clarity-through-layout)).
- **No em dashes in public-facing text**: Do not use em dashes in player-facing UI copy, store metadata, release notes, or other public-facing text.
- **Perceptible feedback**: Every supported player action needs prompt, perceptible feedback ([Design principles](Docs/Product/DesignPrinciples.md)); existing visible responses count.
- **First-party SwiftUI**: Follow the [platform policy](Docs/Platform/ApplePlatformReference.md#platform-support). The deployment target is a floor, not an adoption ceiling; avoid legacy compatibility frameworks and UIKit feature chrome.
- **Artwork budgets**: Preserve launch/imminent artwork pins and first-screen prepared artwork; do not replace them with on-demand `Image(name)` or lower [artwork budgets](Docs/Platform/PerformanceInvestigationPlaybook.md) without product approval.
- **Data compatibility**: Preserve or migrate saves, serialized identifiers, manifests, and live schemas unless the consumer window is proven closed or a break is approved.
- **Localization**: Player-facing text changes must complete [localization](Docs/Platform/Localization.md#agent-workflow) in the same task via `python3 Scripts/localization.py run` (every configured language plus an independent AI review; never copy English or fabricate review records).
- **Test restraint**: Add tests only for consequential gaps in existing protection ([Testing](Docs/Platform/Testing.md#coverage-decision-new-and-changed-behavior)); verification does not require new test code.

## Scope and communication

- **Stay scoped and autonomous**: Work through implementation, verification, and fixes caused by the change without extra approval checkpoints. Adopt adjacent defects only when clearly in scope and reversible. Propose unresolved product, migration, dependency, or broad architectural decisions before acting.
- **Player-facing reporting**: Write for someone who knows Trinket as a game. Distinguish verified behavior from inference, and report what checks ran alongside any skips or blockers ([completion states](Docs/Platform/Verification.md#completion-states)).
- **Independent chats**: Only message another chat for a concrete unresolved dependency or conflict that cannot be answered from the repository. Do not send status broadcasts, acknowledgments, or wake completed chats.
