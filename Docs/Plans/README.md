# Plans

Living product and platform rules belong in their canonical documentation owners.
Keep implementation plans here only while work is in flight. When work completes
or is cancelled, fold durable requirements and actionable blockers into their
canonical owners and delete the plan. Do not create outcome archives.

Plans require front matter with `type: execution-plan`, a status (`active` or
`blocked`), `created`, `updated`, and `expires`. Blocked plans also require a
`reason`. `expires` is an advisory review date: checks warn near or after it,
without requiring date-only renewals. Updates may follow that date; malformed
metadata still fails validation. Review the disposition when resuming the work.

Final handoff rejects remaining active plans in the task's file scope unless
intentionally unfinished work is passed with `--keep-plan` to handoff and
`integrate --keep-plan` at landing. Include the task's plan
in that scope, including when deleted. Unscoped and hosted documentation checks remain global.
Direct `check-docs.py` and `check-plans.py` calls accept `--paths <files...>` for
scope; omitting it checks all active plans. `check-docs.py --paths` also scopes
link checks to edited documents and inbound dependencies, and structural checks
to affected owners. Standalone `check-plans.py` retains global metadata validation
while scoping final closure.

Use `./Scripts/new-plan.sh <PlanName>` to scaffold metadata. Execution plans are
allowed only directly under this directory; supporting design reference images
may accompany active work. Report the outcome in the task handoff.

Keep each plan to its objective, boundaries, status, blockers, next actions and
evidence. Link the [standing workflow](../../AGENTS.md#route-and-read) and
[verification policy](../Platform/Verification.md); add only task-specific acceptance
criteria rather than repeating those procedures. Run history belongs in handoffs or
retained deliverables. Git preserves revisions; condensation neither completes
unfinished work nor renews its authorization.
