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

1. **Resolve conflicting diagnostic instructions.** The shared-machine guidance
   in the root agent instructions and `/Users/ryanmcintire/Developer/.coordination/README.md`
   calls for retrying timed-out focused checks, while
   [Verification](../Platform/Verification.md#single-focused-local-diagnostic)
   says not to retry automatically. It also gives a 30-second lane wait while the
   shared-machine instructions specify 900 seconds for essential heavy work; the
   intended treatment of focused diagnostics needs an explicit reconciliation.
   These are different from the common 30-second execution budget. Conflicts
   create uncertainty precisely when a test times out or the machine is busy.
2. **Make the ordinary path easier to follow end to end.** A task uses worktree
   creation, path briefing, handoff, review, commit, protected integration and
   cleanup, with details split among the root guide, Development, Verification,
   and script help. The existing briefing already prints the normal next steps;
   the answer is to improve that entry point, not add another guide or wrapper by
   default. An intentionally retained plan needs `--keep-plan` at landing, but
   the sample plan briefing did not mention it.
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
5. **Measure copy-change and compatibility overhead.** Player-facing copy requires
   all configured locales and a separate AI review under
   [Localization](../Platform/Localization.md#agent-workflow). The workflow has
   resumable automation and retains legacy commands. Review where agents actually
   spend effort or encounter failures before changing it; this review alone does
   not establish that translations or independent review are unnecessary. Likewise,
   compatibility flags and helpers may have consumers and should not be deleted
   based on their names or count.

## Implementation plan

- [ ] **P0 — Establish one resource-policy answer.** Reconcile focused-test retry,
  admission wait, execution deadline, and authorization across the supplied
  machine instructions, shared coordination guidance, and Trinket verification
  owner. Preserve the 30-second focused execution limit and one worker. Identify
  the owner of cross-repository rules and coordinate changes there; do not silently
  weaken those rules in Trinket. Add a short decision table and ensure command
  examples and failure messages match the resulting policy.
- [ ] **P1 — Streamline the common workflow.** Exercise briefing, handoff and
  landing for representative documentation, Swift logic, UI and localization
  changes. Record steps, repeated lookups, confusing output and actual elapsed
  time where safe. Make the existing briefing surface the relevant next command,
  exceptions and evidence state, including retained-plan landing when applicable.
  Remove duplicated or stale guidance from its current owner; preserve the CLI
  and its existing consumers. Keep detailed recovery information available on
  demand rather than forcing it into every task.
- [ ] **P1 — Investigate cancellation with owned fixtures.** Reproduce the
  surviving-child report using isolated, task-owned processes and private locks.
  Trace the runner and host-lane ownership boundaries before changing them. If
  reproducible, fix the responsible owner and add a targeted regression that checks
  descendants and lock release without signaling foreign work. If not, retain the
  evidence and a precise unresolved limitation instead of claiming a fix.
- [ ] **P2 — Make visual inspection failures actionable.** Exercise the existing
  native fallback and bounded Duo diagnostics when the necessary environment is
  available. Improve diagnostics or a single routed recovery path only where
  supported by evidence; distinguish app state, capture, display and input failures.
  Preserve managed leases and never terminate foreign processes. Report any
  platform/tool limitation that remains outside repository control.
- [ ] **P2 — Audit translation and legacy workflow costs.** Sample a small copy
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
  and delete this plan when its accepted work is complete. Record unresolved
  external prerequisites and distinguish local evidence from hosted CI.

## Status and blockers

Planning only; no workflow changes or timing measurements have been made. The
cross-repository policy reconciliation needs its shared owner and must respect
instructions supplied to each session. Simulator and Duo work depends on available
tooling; do not promise a fix before reproducing the cause.
