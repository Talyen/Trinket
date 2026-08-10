# CI fixer bot

Solo trunk workflow: agents push `main` after local pre-push / handoff gates; GitHub Actions (`Trinket CI` / `Trinket PR`) is the comprehensive post-push gate; the Cursor automation **CI Autofix — Trinket** recovers red `main` without blocking direct pushes.

Keep the live Automations prompt in sync with the **Automation prompt** section below when policy changes.

## Gate model

| Path | Policy |
| ---- | ------ |
| Direct push to `main` | Allowed. Do **not** require `tests / CI OK` as a push gate (chicken-and-egg). Local `./Scripts/handoff.sh --isolate` / pre-push + post-push CI. |
| Merge PR into `main` | Require status check **`tests / CI OK`**. Admin bypass exists so owners/agents can still push trunk directly; the Cursor App is not bypassed, so fixer auto-merge waits for green CI. |
| Fixer merge method | **Always open a squash PR**, then enable auto-merge only (`gh pr merge --auto --squash`). Never `--admin`, never force-merge, never leave a fix only on a `cursor/ci-fix-*` branch. |

See also [AGENTS.md](../AGENTS.md) (commit/push) and [Docs/Platform/Testing.md](Platform/Testing.md).

## Tiers

### Tier A — open PR and auto-merge

Safe, mechanical recoveries:

- SwiftFormat / SwiftLint / style gate
- XcodeGen / generated-output drift (`./Scripts/assert-generated-output.sh`)
- Asset codegen gate
- Toolchain pin mismatches in `Scripts/tool-versions.env` when runners require a newer Xcode (document the Apple FB / crash if known)
- Mechanical test or assertion drift after renames/API shape changes
- **Tooling-only timeouts** in script/smoke harnesses — prefer speeding the script or narrowing scope; dedicated higher timeout only with a clear rationale. Do **not** skip the test.

### Tier B — escalate, do not open a fix PR

- Product / battle rules / game balance
- Saves, CloudKit, migrations, schema
- Unclear root cause
- Flaky simulator / UI tests without a mechanical selector fix
- Infrastructure outages (Actions / runner image unavailable) — note re-run; no code change

### Out of scope (never)

- Skipping tests or deleting coverage to greenwash
- Weakening assertions to match broken behavior
- Changing game logic, battle rules, or save formats to silence CI

## Tier B fingerprint dedupe

Mirror the Nightly open-or-update pattern (label + single sticky issue). GitHub Issues must stay **enabled** on this repo.

1. Derive a stable **fingerprint** from failing job names + primary error signature (file + message class), e.g. `ci-fail-build` + `actool AppIcon.icon`.
2. Search open issues with label `ci-autofix-failed` whose title/body match that fingerprint.
3. **If found:** comment with the new Actions run URL, commit SHA, and any new notes — then **stop**.
4. **If not found:** create one issue labeled `ci-autofix-failed` with run URL, SHA, failing jobs, why it is Tier B, and suggested human/agent follow-up.

Do not open a new issue per SHA for the same fingerprint. Do not stop after pushing a `cursor/ci-fix-*` branch with no PR.

## Automation prompt

Copy everything in this section into the Cursor automation instructions when updating the live bot (**CI Autofix — Trinket**).

```text
You are the Trinket CI fixer for repo Talyen/Trinket (SwiftUI / Xcode / SPM).

When CI fails on main:
1. Read the failing run logs and classify Tier A vs Tier B using Docs/CI-FIXER.md (checked in).
2. Tier A: branch from the failing main SHA, apply the minimal fix, open a squash PR (required — do not leave a branch-only fix), enable auto-merge only (`gh pr merge --auto --squash`). Never --admin or force-merge. Wait for required check "tests / CI OK".
3. Tier A includes SwiftFormat/SwiftLint, XcodeGen/generated drift, asset codegen, toolchain pins in Scripts/tool-versions.env, and tooling-only timeouts (never skip tests).
4. Tier B: do not open a fix PR. Deduplicate: search open issues with label ci-autofix-failed matching the failure fingerprint; if one exists, comment the new run URL and stop; else create one issue with that label. Issues are enabled on this repo.
5. Never skip tests, weaken assertions, or change game/save/battle logic to greenwash.
6. PR body: summary, verification commands (e.g. ./Scripts/test.sh style, path-scoped handoff), link to the failing Actions run. Mention Tier A auto-merge when applicable.
7. If both Tier A and Tier B fail on the same run: land the Tier A PR for the mechanical part and escalate the Tier B fingerprint separately (deduped).
```

## Hygiene

- Label: `ci-autofix-failed` (bot escalations).
- Delete fixer branches on merge (repo `delete_branch_on_merge`).
- After resolving a sticky Tier B issue, close it; do not leave duplicate open issues for the same fingerprint.
