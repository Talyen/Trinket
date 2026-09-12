# Plans

Living product and platform rules belong in their canonical documentation owners.
Keep implementation plans here only while work is in flight; completed and
cancelled plans become one-line records in [Archived/README.md](Archived/README.md),
with full execution detail retained in Git history.

Plans require front matter with `type: execution-plan`, a status (`active` or
`blocked`), `created`, `updated`, and `expires`. Blocked plans also require a
`reason`. `expires` is an advisory review date: checks warn near or after it,
without requiring date-only renewals. Updates may follow that date; malformed
metadata still fails validation. Review the disposition when resuming the work.

Final handoff rejects remaining active plans in the task's file scope unless
intentionally unfinished work is passed with `--keep-plan`. Include the task's plan
in that scope, including when deleted. Link and structural checks remain global.
Direct `check-docs.py` and `check-plans.py` calls accept `--paths <files...>` for
final closure scope; omitting it checks all active plans.

Use `./Scripts/new-plan.sh <PlanName>` to scaffold metadata. Execution plans are
allowed only directly under this directory; supporting design reference images
may accompany active work. When a plan finishes, fold durable rules into their
canonical owners, record its outcome in the archive index, and delete the plan.
