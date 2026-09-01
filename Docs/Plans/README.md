# Plans

Living product and platform rules belong in `Docs/Platform/`, package READMEs, and feature `AGENTS.md` files. Keep implementation plans in this folder only while work is in flight; completed and cancelled plans become one-line records in [`Archived/README.md`](Archived/README.md), while their full text remains available in Git history.

This folder may hold design reference images and **active agent execution plans** while work is in flight. Plans require front matter with `type: execution-plan`, a status (`active` or `blocked`), `created`, `updated`, and an `expires` date. `check-docs.py` allows valid unexpired active plans, warns near expiry, and rejects missing or stale metadata. When a plan finishes, add its outcome to `Archived/README.md`, fold durable rules into their canonical owner, and delete the active plan. Git retains the full execution record.

Final handoff checks reject remaining active plans unless the intentionally unfinished work is passed with `--keep-plan`. Use `./Scripts/new-plan.sh <PlanName>` to scaffold valid metadata. Execution plans anywhere outside this directory are rejected.
