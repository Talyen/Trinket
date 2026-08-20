# Plans

Do not keep completed implementation plans or historical rollout records here. Living product and platform rules belong in `Docs/Platform/`, package READMEs, and feature `AGENTS.md` files.

This folder may hold design reference images and **active agent execution plans** while work is in flight. Plans require front matter with `type: execution-plan`, a status (`active` or `blocked`), `created`, `updated`, and a future `expires` date. `check-docs.py` allows valid unexpired plans, warns near expiry, and rejects missing, stale, complete, or cancelled plans. When a plan is finished, delete it or fold durable rules into `Docs/Platform/` — do not archive completed rollouts here.

Final handoff checks reject remaining active plans unless the intentionally unfinished work is passed with `--keep-plan`. Use `./Scripts/new-plan.sh <PlanName>` to scaffold valid metadata. Completed work lives in git history and handoff/PR notes.
