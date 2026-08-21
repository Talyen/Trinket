---
type: execution-plan
status: complete
created: 2026-08-20
updated: 2026-08-21
expires: 2026-09-19
---

# AI agent token-efficiency plan

> Superseded by [`DocsToolingSimplification.md`](DocsToolingSimplification.md).

## Objective

Reduce avoidable agent context, diagnostic noise, and transient-artifact
retention while preserving correctness gates, source ownership, and the
path-scoped verification model. This is process/tooling work; production game
behavior is out of scope.

## Current direction

The documentation and routing portions of this work are consolidated in
[`DocumentationSimplificationPlan.md`](DocumentationSimplificationPlan.md).
That plan owns the source-of-truth map, required/optional reads, command/test
guidance, audit boilerplate, and stale-reference cleanup.

The remaining tooling work is intentionally small and evidence-driven:

- Diagnostics default to the current run, with concise root-cause-first output;
  historical payloads require an explicit path or keep/full option.
- Test, performance, balance, and raw-log artifacts are run-scoped and cleaned
  after classification by default; warm build caches are not report artifacts
  and are not removed by this policy.
- `agent-context` remains explicit-path and isolated by default. Routing should
  attach only the semantic owner card and applicable skill.
- Broad/whole-tree classification remains available as an intentional escape
  hatch and must not weaken any verification gate.

## Guardrails

- Do not weaken `handoff.sh`, package tests, smoke tests, generated-output
  checks, module boundaries, or failure detection to shorten output.
- Do not delete authored source or warm build caches as report cleanup.
- Preserve durable failure classification, source locations, annotations, and
  explicit forensic access to retained raw artifacts.
- Prefer existing scripts and owners. Add a new abstraction only when a
  confirmed current boundary needs it; do not add a generic telemetry or
  duplicate-text framework.
- Keep this plan short. Disposable benchmark transcripts, raw logs, and model-
  specific token tables do not belong in a living plan.

## Implementation order

1. Make diagnostics run-scoped and bound the default narrative.
2. Make cleanup safe, current-run-only by default, and explicit to retain.
3. Narrow `agent-context` routing and keep the read contract deterministic.
4. Implement the documentation ownership changes in
   `DocumentationSimplificationPlan.md`.

## Verification

- `./Scripts/test-scripts.sh`
- Focused diagnostics, routing, cleanup, and keep-mode regressions for each
  changed script.
- `python3 ./Scripts/check-docs.py`
- Path-scoped isolated handoff for the changed script/docs paths.

When this work is complete, fold durable policy into `Scripts/README.md`,
`Docs/Platform/Verification.md`, or the relevant AgentContext card, then mark
this plan complete and move it to `Docs/Plans/Archived/`.
