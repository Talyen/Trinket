# CI fixer

Solo trunk workflow: agents push `main` after local pre-push / handoff gates; GitHub Actions (`Trinket CI` / `Trinket PR`) is the comprehensive post-push gate. Direct pushes stay allowed; red `main` is recovered without blocking them.

Keep the live **CI Autofix — Trinket** Automations prompt in sync with the **Automation prompt** section below when policy changes.

## Who does what

| Owner | Responsibility |
| ----- | -------------- |
| **Actions** (`CI failure issue`) | When `Trinket CI` fails on `main`, create or comment on one sticky issue titled **CI failing on main** (same open-or-update pattern as Nightly). Deterministic; no LLM. |
| **Cursor** (`CI Autofix — Trinket`) | **Tier A only**: fix → squash PR + auto-merge when no user-facing design judgment is required. Never create, comment on, or manage GitHub issues. If unsure, exit without changing the repo. |

GitHub Issues must stay **enabled** on this repo so the sticky workflow can post.

## Gate model

| Path | Policy |
| ---- | ------ |
| Direct push to `main` | Allowed. Do **not** require `tests / CI OK` as a push gate (chicken-and-egg). Local `./Scripts/handoff.sh --isolate` / pre-push + post-push CI. |
| Merge PR into `main` | Require status check **`tests / CI OK`**. Admin bypass exists so owners/agents can still push trunk directly; the Cursor App is not bypassed, so fixer auto-merge waits for green CI. |
| Fixer merge method | **Always open a squash PR**, then enable auto-merge only (`gh pr merge --auto --squash`). Never `--admin`, never force-merge, never leave a fix only on a `cursor/ci-fix-*` branch. |

See also [AGENTS.md](../AGENTS.md) (commit/push) and [Docs/Platform/Testing.md](Platform/Testing.md).

## Tier A — Cursor may open a PR

**Rule:** fix it if a competent engineer could choose the repair without a user-facing design judgment call (look-and-feel, copy tone, layout taste, new UX, game feel/balance). Prefer the smallest change that restores the intended existing behavior or keeps tooling/CI healthy.

In scope (examples, not exhaustive):

- Style / lint / format gates
- XcodeGen / generated-output drift / asset codegen
- Toolchain pins, script harnesses, CI config, diagnostics, timeouts (never skip tests)
- Compile errors, API renames, test harness drift, broken selectors/identifiers after refactors
- Crashes, logic bugs, and assertion failures where the correct behavior is already specified by tests, docs, or an obvious prior intent — not a new product decision
- Save/schema/CloudKit fixes that restore compatibility or repair breakage without inventing a new player-facing model

## Not Tier A — leave to the sticky issue

- User-facing design judgment (visual design, animation feel, marketing/UI copy voice, layout taste, new interaction patterns)
- Game balance / combat feel / reward tuning as a product choice
- Ambiguous product behavior with no clear specified intent
- Infrastructure outages (Actions / runner image unavailable) — note re-run; no code change

When unsure whether a fix needs design judgment: **do not fix**; leave it on the sticky issue.

## Out of scope (never)

- Skipping tests or deleting coverage to greenwash
- Weakening assertions to match broken behavior
- Inventing new game rules, UX, or save formats to silence CI
- Opening or updating GitHub issues from the Cursor automation (Actions owns that)

## Automation prompt

Copy everything in this section into the Cursor automation instructions when updating the live bot (**CI Autofix — Trinket**).

```text
You are the Trinket CI fixer for repo Talyen/Trinket (SwiftUI / Xcode / SPM).

When CI fails on main:
1. Read Docs/CI-FIXER.md and the failing run logs. Tier A = any fix that does not require a user-facing design judgment call (look-and-feel, copy tone, layout taste, new UX, game feel/balance). If unsure, treat as not Tier A.
2. If not Tier A: do nothing to the repo and exit successfully. Actions already opens/updates the sticky issue "CI failing on main". Never create, comment on, label, or close GitHub issues.
3. If Tier A: branch from the failing main SHA, apply the minimal fix that restores intended existing behavior or healthy tooling/CI, open a squash PR (required — do not leave a branch-only fix), enable auto-merge only (`gh pr merge --auto --squash`). Never --admin or force-merge. Wait for required check "tests / CI OK".
4. In scope includes style/lint, codegen drift, toolchain/CI/scripts, compile/API/test harness fixes, and bug fixes with clear specified intent — not new product/design decisions.
5. Never skip tests, weaken assertions, invent game/UX/save behavior, or greenwash.
6. PR body: summary, verification commands (e.g. ./Scripts/test.sh style, path-scoped handoff), link to the failing Actions run. Mention Tier A auto-merge when applicable.
```

## Hygiene

- Sticky issue title: **CI failing on main** (Actions). Close it when `main` is green again.
- Nightly uses a separate sticky: **Nightly failing on main**.
- Delete fixer branches on merge (repo `delete_branch_on_merge`).
- Legacy label `ci-autofix-failed` is unused by the new split; close leftover issues from the old prompt-driven path when convenient.
