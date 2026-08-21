---
type: execution-plan
status: complete
created: 2026-08-21
updated: 2026-08-21
expires: 2026-09-20
---

# DocsToolingSimplification

> Completed 2026-08-21. All work items landed. One deliberate adjustment: the
> five lock sites were not unified into a single generic helper — they split
> into two mechanisms (noclobber-file vs mkdir-dir) with different stale-reap
> and retry semantics, so unification would have changed concurrency behavior.
> `run-env.sh` instead gained shared `trinket_slot_owner_token` /
> `trinket_lock_claim_file` helpers covering the three file-lock families; the
> mkdir-dir locks in `generate.sh` and `performance.sh` stay as-is.

## Objective

Finish the repository simplification effort by removing dead weight, residual
duplication, stale references, and over-engineering across `.agents/skills/`,
`Scripts/`, and the remaining documentation surface. Convert prose rules into
enforced checks where cheap. No verification gate is weakened; no game behavior
changes.

This plan supersedes and absorbs `DocumentationSimplificationPlan.md` and
`TokenEfficiencyPlan.md` (see Disposition).

## Context and constraints

- The working tree contains a large uncommitted implementation of the prior
  documentation-simplification plan (~93 modified files). This task builds on
  top of it without committing, stashing, or reverting any of it.
- All verification uses explicit `--paths` scoped to files this task touches,
  so pre-existing modifications never enter our gate. Nothing is staged or
  committed unless separately requested.
- Script consolidation depth is medium: deletions plus behavior-preserving
  dedupe. The diagnostics Python family rewrite and large-function
  decomposition are out of scope.

## Disposition of prior plans

At Phase 0, audit which `DocumentationSimplificationPlan.md` items the current
working tree already satisfies. Fold any genuinely unfinished items into this
plan's work items, then mark both predecessor plans complete with a "superseded
by DocsToolingSimplification" note and move them to `Docs/Plans/Archived/`.
Exactly one active plan remains.

## Work items

### 1. Skills (`.agents/skills/`) — case-by-case

| Skill | Verdict | Action |
|---|---|---|
| `run-audits` | Keep | Unchanged; real orchestration workflow cited by `Docs/Audits/README.md` |
| `architect` | Keep, slim to ~8 lines | Keep only "draft public API surface before implementation". Drop the DAG list (`check-module-boundaries.sh` enforces it) and the three-use rule (`AGENTS.md` owns it) |
| `doc-budget` | Keep, trim to ~12 lines | Sole owner of comment-hygiene policy; drop the vague token-hygiene step |
| `qa-verifier` | Remove | Restates the `Verification.md` confidence ladder with commands `agent-context.sh` already prints per path |
| `handoff-verifier` | Remove | Content is owned by `AGENTS.md` (isolated handoff; readable summary) |
| `unslop` | Remove | Near-verbatim restatement of `AGENTS.md` change discipline; never attached despite its description |
| `blast-radius` | Remove | Generic research habits with no repo-specific content |
| `why` | Remove, salvage two lines | Fold its `Decisions.md` + `Proposals.md` pointers into `Docs/AgentContext/battle-balance.md` |

The classifier attaches only `doc-budget`, `architect`, and the apple-design
skill, so removals need no router edits. Update the skill-name list in the
root `AGENTS.md` Task routing section to name only surviving skills.

### 2. Dead weight — delete outright (verified zero external callers)

| Item | Action |
|---|---|
| `Scripts/test-iterate.sh` | Delete; remove its `Scripts/README.md` row (`test.sh` owns warm-build reruns) |
| `Scripts/validate-manifests.sh` | Delete; remove the `ContentManifest/README.md` reference (`generate.sh` already runs `content_codegen validate`) |
| `agent-context.sh --json` mode | Delete the hand-rolled JSON emitter and usage text; no consumer exists |
| `ci-diagnostics.sh --all` / `--prune-successes`; `diagnostic_maintenance.py prune()` | Delete modes; CI uses only reset/stage/cleanup; merge prune into cleanup |
| `ci-diagnostics.py --session` / `--full` | Delete if the implementation grep confirms no callers |
| `xcode-runner.sh --max-attempts` | Delete flag; retry path hardcodes its value |
| `handoff.sh run_check` branches `assert committed` / `assert assets` | Delete; the classifier never emits them |
| Never-set env knobs in `run-env.sh`: `TRINKET_KEEP_DIAGNOSTICS`, `TRINKET_ARTIFACT_MAX_AGE_DAYS`, `TRINKET_SIM_SLOT_SKIP_ACQUIRE`, `TRINKET_CLEANUP_IDLE_POOL`, legacy alias `TRINKET_CLEANUP_EXCESS_SIMULATORS` | Delete knobs, their code paths, and their test coverage after a final setter sweep |
| `test.sh smoke-full` | Collapse into bare `smoke`; update CI callers and the tier rows in `Scripts/README.md` + `Verification.md` |

Deleting each thing removes its documentation line with it.

### 3. Stale references and router consistency fixes

- `Docs/AgentContext/ci-diagnostics.md` references a CI input
  `keep-diagnostics` that no workflow defines — remove or replace with the
  real mechanism.
- Same card hardcodes the diagnostic budget numbers that
  `Scripts/config/diagnostic-limits.env` exists to own — replace with a
  pointer.
- `Docs/AgentContext/battle-balance.md` is emitted by no route in
  `Scripts/change-classification.sh` — add a route (balance-sweep /
  `BalanceSweepCLI` paths) or mark it lookup-only explicitly in the AgentContext
  README.
- Align the AgentContext README trigger table with actual routes (for example,
  `TrinketFeatureSupport` paths currently emit no card despite the table).
- Replace remaining mutable snapshots in cards (generated filenames,
  talent-node counts, boss-HP ratios, SwiftUI API allowlists) with stable
  symbols or pointers.

### 4. Documentation deduplication (one fact, one owner)

Cards:

- SaveTestSupport location: one owner (`persistence.md`); other four mentions
  become links.
- UI-test rubric: `Testing.md` only; cards link.
- Push/PR policy: root `AGENTS.md` + `Verification.md` only;
  `ci-and-project-generation.md` keeps exceptions only.
- BattleFeature↔AppState import ban and "no parallel `AppState.battle`": one
  owner each; other mentions link.
- Merge `battle-runtime.md` + `battle-presentation.md`; fold `battle.md`'s
  concern table into its subcards or the README.

Audits:

- Strip the repeated deferral-to-proposal-bar sentence (~12 guides),
  "clean pass is valid" restatements, and the intentional-seams allowlist down
  to a single owner (`Docs/Audits/README.md` contract; seams already recorded
  in `Proposals.md`).
- Audit 13's ownership tables become a link to `Architecture.md`.

Packages:

- `TrinketTestSupport` README/AGENTS near-verbatim pair → one file's worth of
  content.
- `TrinketCore` and `TrinketBattleRuntime` AGENTS → pure deltas over their
  READMEs.

Manifests:

- One shared media-pipeline section in `content-and-manifests.md`; the four
  media READMEs keep only schema/settings.
- Delete `ContentManifest/README.md`'s generated-file inventory (it contradicts
  the TrinketContent README rule against second inventories).

### 5. Automation additions (`Scripts/check-docs.py`)

- Router↔card consistency check: every non-lookup card under
  `Docs/AgentContext/` must appear in an `add_context_card` call in
  `Scripts/change-classification.sh`, and README trigger-table rows must
  correspond to real routes.
- Add targeted stale phrases for the stripped audit boilerplate (the
  proposal-bar deferral sentence and the clean-pass validity sentence) so they
  cannot silently return. No general prose linter.

### 6. Script consolidation (behavior-preserving)

- One lock acquire/reap helper under `Scripts/lib/` replacing the five copies
  (`run-env.sh` sim slots, UI slots, cleanup locks; `generate.sh`
  `acquire_generation_lock`; `performance.sh`) and the repeated `BASHPID`
  owner-token expression.
- Shared pinned-tools preamble function for `ci-gate.sh`,
  `ci-assets-gate.sh`, `agent-push-gate.sh`.
- `agent-push-gate.sh` reuses `assert-generated-output.sh`'s committed-drift
  check (add an include-pbxproj parameter) instead of re-implementing it.
- `ensure-ci-tools.sh`: one parameterized install skeleton for the three
  download→checksum→extract tools.
- `test.sh`: extract the repeated simulator/parallel flag pairs in mode
  dispatch.

## Out of scope

- Diagnostics Python family consolidation beyond dead-mode deletion.
- Decomposing large functions (`xcode_runner_run`, `trinket_classify_path`,
  `run_one_package`, `print_agent`).
- Apple-design skill rework (owned by prior-plan items already in the tree).
- Any gate weakening, verification demotion, or game-behavior change.

## Sequencing

1. Phase 0 — Disposition: audit prior-plan completion, fold unfinished items
   here, archive both predecessors.
2. Phase 1 — Deletions and stale fixes (skills, scripts, flags, knobs,
   references).
3. Phase 2 — Documentation deduplication.
4. Phase 3 — Automation additions and script dedupe.
5. Completion — final verification, mark complete, archive this plan.

## Verification

- `./Scripts/test-scripts.sh`
- `python3 Scripts/check-docs.py`
- `./Scripts/ci-gate.sh`
- Explicit-`--paths` isolated handoff over touched files only:
  `./Scripts/handoff.sh --isolate --paths <touched-files...>`
- Repo-wide grep sweeps proving deleted names (skills, scripts, flags, knobs)
  have no dangling references.

## Success criteria

- No unreferenced skill, script, flag, mode, or env knob remains; every
  deleted name has zero dangling references.
- Every duplicated fact has one obvious owner; cards hold only
  path-triggered exceptions; most audit guides sit under ~30 lines.
- `check-docs.py` fails if a context card becomes unreachable or the trigger
  table drifts from real routes.
- Net reduction of roughly 600–800 documentation lines and 500–700 script
  lines with all gates green.
