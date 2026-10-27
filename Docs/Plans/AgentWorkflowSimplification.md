---
type: execution-plan
status: active
created: 2026-10-27
updated: 2026-10-27
expires: 2026-11-10
---

# Simplify agent workflows

## Objective and boundaries

Reduce the decisions, contradictory instructions, and manual recovery agents face
when changing Trinket. Keep player-facing quality, save compatibility, isolated
work, protected integration, host resource limits, and honest verification evidence.
Do not trade away a safeguard just to shorten the instructions. The normal
[workflow](../../AGENTS.md#route-and-read) and
[verification policy](../Platform/Verification.md) remain authoritative until
their owners are deliberately updated.

This plan is a source and documentation review, not a measured time study. Rank
changes by observed friction and validate the gains on representative tasks before
removing mechanisms. Do not push or publish as part of this plan without authorization.

## Evidence and priorities

1. **Diagnostic policy reconciled.**
   [Verification](../Platform/Verification.md#single-focused-local-diagnostic)
   and automatic admission now match the supplied shared-machine instructions:
   up to 900 seconds for admission, a 30-second focused execution limit, and
   retrying a timeout under the same limits. Admission wait is not execution time.
2. **Make the ordinary path easier to follow end to end.** A task uses worktree
   creation, path briefing, handoff, review, commit, protected integration and
   cleanup, with details split among the root guide, Development, Verification,
   and script help. The existing briefing already prints the normal next steps;
   the answer is to improve that entry point, not add another guide or wrapper by
   default. The briefing now explains `--keep-plan` when an active plan is in scope;
   representative end-to-end timing is still outstanding.
3. **Repair cancellation ownership.** The
   [friction log](../../.agents/FRICTION_LOG.md) records surviving descendants
   after task-owned runners were terminated. `Scripts/lib/lock.sh` attempts to
   collect descendants, but the cause is not established. This forces manual
   process-ownership investigation and can leave work consuming shared resources.
4. **Reduce simulator recovery guesswork.** The friction log records Device Hub
   attachment timeouts and unreliable Duo display routing; the
   [native interaction fallback](../../.agents/skills/device-interaction/SKILL.md)
   and [Duo guidance](../Platform/SimulatorOperations.md#duo-display-routing)
   already exist. These are observed tooling limitations, not proof that the app
   is broken or that a repository-only fix exists.
5. **Make the verification decision executable.** A focused diagnostic requires
   agents to combine a concrete selector, a local opt-in, single-worker settings,
   a 30-second execution deadline, a separate admission wait and an outer host-lane
   wrapper. The visual route has different authorization and evidence requirements.
   [Verification](../Platform/Verification.md#confidence-ladder) explains these,
   but the agent still assembles the command and interprets multiple layers of
   output. This is a source-review finding, not a measured failure rate.
6. **Fix a concrete command-reference mismatch.**
   [Scripts/Reference.md](../../Scripts/Reference.md#development) says briefing
   defaults to the complete task against `main`, but `python3 Scripts/agent-brief.py`
   exits with an error unless given `--paths`, `--working-tree`, `--base` or
   `--task`. Handoff does have a complete-task default. An agent following the
   reference can choose the wrong invocation or scope.
7. **Measure copy-change and compatibility overhead.** Player-facing copy requires
   all configured locales and a separate AI review under
   [Localization](../Platform/Localization.md#agent-workflow). The workflow has
   resumable automation and retains legacy commands. Review where agents actually
   spend effort or encounter failures before changing it; this review alone does
   not establish that translations or independent review are unnecessary. Likewise,
   compatibility flags and helpers may have consumers and should not be deleted
   based on their names or count.

## Implementation plan

- [x] **P0 — Establish one resource-policy answer.** Reconcile focused-test retry,
  admission wait, execution deadline, and authorization across the supplied
  machine instructions, shared coordination guidance, and Trinket verification
  owner. Preserve the 30-second focused execution limit and one worker. Identify
  the owner of cross-repository rules and coordinate changes there; do not silently
  weaken those rules in Trinket. Add a short decision table and ensure command
  examples and failure messages match the resulting policy.
- [x] **P1 — Correct the briefing scope mismatch.** Choose and document the
  intended behavior after checking current callers: either provide the promised
  complete-task default or state the required selector and give the exact
  complete-task invocation. Test the no-argument behavior and scope of committed,
  dirty, deleted and renamed task paths as applicable; retain existing explicit
  selectors and consumers. Keep the executable and command reference aligned.
- [ ] **P1 — Streamline the common workflow.** Exercise briefing, handoff and
  landing on naturally occurring documentation, Swift logic, UI and localization
  tasks. Record actual elapsed time, repeated lookups and confusing output where
  practical; distinguish task work and waiting from workflow overhead. Compare
  equivalent evidence before claiming improvement. Make changes only for observed
  friction; preserve the CLI, its consumers and on-demand recovery details.
- [x] **P1 — Investigate cancellation with owned fixtures.** Reproduce the
  surviving-child report using isolated, task-owned processes and private locks.
  Trace the runner and host-lane ownership boundaries before changing them. If
  reproducible, fix the responsible owner and add a targeted regression that checks
  descendants and lock release without signaling foreign work. If not, retain the
  evidence and a precise unresolved limitation instead of claiming a fix.
- [x] **P1 — Route verification without manual flag assembly.** Use the existing
  briefing or handoff preview to present the exact next command for an ordinary
  task, one explicitly selected focused diagnostic, and a visual inspection. Show
  local versus hosted obligations, admission versus execution limits, and the
  missing input when the selector or authorization cannot be inferred. Prefer
  existing entry points and avoid a new mandatory wrapper. Do not infer permission
  for broader work or claim a preview is evidence. Cover the routes and refusal
  cases with targeted tooling fixtures and compare their output with the policy.
- [ ] **P2 — Make visual inspection failures actionable.** Exercise the existing
  native fallback and bounded Duo diagnostics when the necessary environment is
  available. Improve diagnostics or a single routed recovery path only where
  supported by evidence; distinguish app state, capture, display and input failures.
  Preserve managed leases and never terminate foreign processes. Report any
  platform/tool limitation that remains outside repository control.
- [x] **P2 — Audit translation and legacy workflow costs.** Sample a small copy
  change without committing it or inventing review evidence; inspect existing
  recovery and cache behavior. Identify a concrete bottleneck before proposing
  an automation improvement. Inventory actual references to compatibility options
  and change or retire them only after confirming consumers and migration needs.
  Maintain every supported locale and genuine independent review.
- [ ] **Validate and close.** Compare the representative scenarios against the
  baseline: fewer decisions or recovery steps, correct commands, accurate evidence
  and no lost safeguards. Run focused regressions for changed tooling and the
  appropriate static handoff; use rendered/device evidence only when the change
  actually requires it. Update canonical owners, remove resolved friction entries,
  and delete this plan when its accepted work is complete. For each sampled
  scenario, compare the number of required manual decisions and document lookups
  with the baseline, verify the emitted command and reported evidence, and record
  waiting separately. A smaller instruction count alone is not proof of improvement.
  Record unresolved external prerequisites and distinguish local evidence from
  hosted CI.

## Measurement approach

Use existing task handoffs and naturally occurring work; do not create synthetic
product changes or a new telemetry service to fill a sample. Retained task and
verification reports identify scope, checks and outcomes, but do not record
end-to-end elapsed time or all manual lookups. Missing timing is unknown, not zero.
For future samples, capture brief elapsed timings and concrete detours in the
task's existing deliverables when readily available. For a timed-out focused
diagnostic, record its selector, per-attempt outcome and whether a retry answered
the original question, separately from queue wait. Preserve the 30-second limit
and current retry policy; do not infer a failure rate from one historical case.

## Status and blockers

The command reference now identifies briefing's required scope and `--base main`
for a complete task; existing callers keep their explicit-scope behavior. Scoped
briefing can print a host-admitted focused package-suite or visual command when
provided the selector and owner, with the deadlines and evidence limits visible.
Focused fixtures cover scope endpoints, incomplete selectors and generated command
arguments. These are source and fixture results, not measured end-to-end gains.

This documentation/tooling task supplies one natural workflow sample; equivalent
logic, UI and localization tasks and timings remain outstanding. A fresh managed
iPhone inspection built and launched the app, but native discovery hit the same
existing per-device reservation, whose recorded start was uncertain
and returned no session key. Computer Use reported the Mac locked. The inspection
released its own lease and preserved the reservation; no input or Duo interaction
was exercised. Resume visual recovery after the Mac is unlocked and the reservation's
ownership can be resolved using the existing recovery guidance.

The supplied shared-machine rules now agree with the focused diagnostic example
and automatic host admission. The briefing explains active-plan retention; sample
documentation, logic, UI and localization routes were inspected, but elapsed
end-to-end comparisons and representative landings have not been measured.

The owned nested-shell cancellation fixture passes for INT and TERM; it did not
reproduce the reported surviving compiler or establish the root cause. The friction
log retains that limitation. A temporary store-subtitle change produced seven
pending translations in seven locales in under one second; no AI translation or
review was performed. Existing compatibility flags and manual localization commands
still have documented or test consumers, so none were removed. Failure messages now
point to the automated localization coordinator.

A managed iPhone simulator built and launched Trinket and produced a readable Play
screen capture. Native interaction was blocked by an existing uncertain per-device
reservation; Computer Use again reported the Mac locked on follow-through, and the
user is away. No input or Duo display qualification was performed. Keep the
reservation intact and use the existing native recovery procedure when the Mac
is available; do not infer that the old session has ended. The capture is retained
with task evidence.
