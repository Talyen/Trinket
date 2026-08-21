# Plans

Living product and platform rules belong in `Docs/Platform/`, package READMEs, and feature `AGENTS.md` files. Keep implementation plans in this folder only while work is in flight; completed and cancelled plans are retained in [`Archived/`](Archived/).

This folder may hold design reference images and **active agent execution plans** while work is in flight. Plans require front matter with `type: execution-plan`, a status (`active` or `blocked`), `created`, `updated`, and an `expires` date. `check-docs.py` allows valid unexpired active plans, warns near expiry, and rejects missing or stale metadata. When a plan is finished, set its status to `complete` (or `cancelled`) and run `mv Docs/Plans/<PlanName>.md Docs/Plans/Archived/`; fold any durable rules into their canonical owner as well.

Final handoff checks reject remaining active plans unless the intentionally unfinished work is passed with `--keep-plan`. Use `./Scripts/new-plan.sh <PlanName>` to scaffold valid metadata. Archived plans are historical records and are not considered active work.
