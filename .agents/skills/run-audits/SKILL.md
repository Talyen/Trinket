---
name: run-audits
description: Run one or more Trinket codebase audits from Docs/Audits, including evidence gathering, finding triage, token-efficient subagent implementation, root review, and path-scoped verification. Use when a user asks to run, execute, carry out, or rerun a named audit or all audits in Docs/Audits. Do not treat an uncited audit as backlog merely because it resembles the current task.
---

# Run Trinket audits

Execute audit guides as repeatable evidence-led passes. Keep `Docs/Audits/README.md` as the shared policy source; keep each audit file as the source for its distinct scope, evidence bar, ownership, and hard stops.

## Establish scope

1. Read the applicable `AGENTS.md` instructions.
2. Read `Docs/Audits/README.md` fully.
3. Read `Docs/Audits/Proposals.md`: use its scope baseline for routine passes, and skip open/rejected proposals and accepted non-findings unless new evidence supersedes an entry.
4. Resolve the audits the user cited. “All audits” means every audit Markdown file directly under `Docs/Audits/` except `README.md` and `Proposals.md`; it does not include linked platform playbooks.
5. Read each selected audit fully before probing its scope. Read large sets incrementally rather than dumping the directory into one tool result.
6. Inspect the existing worktree and preserve unrelated changes.

Do not run an uncited sibling audit, broaden an audit into a standing cleanup effort, or manufacture findings. Zero confirmed findings is a successful result.

## Investigate once

Keep the root agent responsible for shared prereads, repository orientation, and the initial evidence inventory.

- Use `./Scripts/agent-context.sh --agent --paths <paths...>` when confirmed candidates identify relevant paths or the task crosses ownership areas.
- Prefer scoped `rg` searches with explicit paths, compiler/linter diagnostics, existing gates, and targeted source reads.
- Avoid whole-repository source dumps, duplicated probes, speculative test runs, and unrelated full suites.
- Treat signals as candidates until the selected audit’s evidence bar confirms impact and ownership.
- Deduplicate overlapping candidates under the owner table in `Docs/Audits/README.md`; one problem produces one finding and one remedy.
- Separate bounded fixes from proposals using the README right-size policy. Follow a confirmed evidence cone across files or packages when required to remove the cause; stop for approval only at the README's architecture, product-policy, live-migration, or high-risk rewrite boundary.

For multiple findings, publish a concise implementation plan before edits. Assign disjoint file or symbol ownership and identify the cheapest matching verification for each slice.

## Delegate implementation efficiently

For a multi-audit run, use subagents only for confirmed, independent implementation slices. For a single audit, stay in the root unless the user requests delegation or multiple disjoint confirmed fixes make it materially useful.

- Use the Worker role for implementation and the Explorer role only for a bounded investigation that does not repeat the root inventory.
- Keep the root as final reviewer. Use the Reviewer role only when the user requests independent review or a high-risk cross-cutting change warrants a second pass.
- Let Codex configuration choose each role’s model and reasoning effort; do not override them in the spawn request unless the user asks.
- Set `fork_turns` to `none` or the smallest useful positive turn count. Never inherit the full thread by default.
- Prefer one or two implementation agents at a time. Spawn more only for truly independent ownership with a clear latency benefit.

Give each subagent a self-contained task brief containing:

- Owning audit and confirmed finding
- Candidate and confirming evidence
- Exact files or symbols it owns
- Preferred remedy and why this size
- Applicable hard stops and repository instructions
- Expected production/test surface direction
- Cheapest matching verification
- Required return format: changed paths, behavior, verification status, and blockers only

Do not ask a subagent to rediscover the finding, read all audit guides, run broad searches, or return raw diffs and full logs. Agents share the worktree, so warn each worker not to alter unrelated or concurrently owned files.

## Review and verify

After each worker finishes:

1. Inspect its diff against the task brief and audit evidence bar.
2. Reject speculative growth, forwarding wrappers, duplicate paths, weakened gates, or tests that fail the repository test-addition rubric.
3. Resolve overlaps centrally; do not have workers overwrite one another.
4. Run focused diagnostics only when a targeted check fails. Keep successful command output quiet or summarized.
5. Run `./Scripts/verify-changed.sh --isolate --paths <integrated changed paths...>` once from the root after integration. Do not multiply the same full gate across workers and root.
6. Review `./Scripts/change-budget.sh` warnings when surfaced and record any necessary justification.

Do not edit audit guides to record results. Record durable proposals and accepted non-findings in `Docs/Audits/Proposals.md` per its hygiene rules, and advance its scope baseline after a completed pass. Put shipped findings, verification, skips, and budget justification in the handoff, commit, or PR requested by the user.

## Handoff

Lead with the outcome and report:

- Confirmed findings fixed, grouped by owning audit
- Audits with zero findings
- Proposals awaiting approval
- Changed authored paths
- Verification commands and pass/fail/skip status
- Any toolchain limitation or change-budget justification

Keep the handoff concise. Summarize diagnostics; never paste long build, test, search, or diff output.
