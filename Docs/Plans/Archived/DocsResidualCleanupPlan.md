---
type: execution-plan
status: complete
created: 2026-08-21
updated: 2026-08-21
expires: 2026-09-04
---

# DocsResidualCleanupPlan

> Completed 2026-08-21. All work items landed in one pass. Two deliberate
> adjustments: local audit severity/triage tables in 03/10/14/15 were kept —
> they map domain examples onto the shared scale, which the Audits README
> explicitly endorses — and `check-docs.py` gained a declared-type index so
> suites nested inside another file (e.g. `PlayerSaveSchemaMigrationTests` in
> `PlayerSaveStoreTests.swift`) do not false-positive. The checker immediately
> caught two extra stale references beyond W1 (`TriggerFieldGroupParityTests`,
> the nonexistent `TrinketBattleRuntimeTests` target and its Testing.md row),
> all fixed here.

## Objective

Remove the documentation drift and duplication a fresh full-tree review found after the two completed simplification passes (`DocumentationSimplificationPlan`, `DocsToolingSimplification`). This pass is smaller than its predecessors: it fixes confirmed stale facts that actively mislead, strips remaining double-ownership text, and adds one targeted checker extension. No gate weakens; no game behavior changes.

## Work items

- [x] **W1 — Confirmed stale facts:** `adjustedMaterialRewards` → `StageCompletion.resolvedMaterialRewards(stageReward:)`; dropped nonexistent `CardActivationTests` and `TrinketBattleRuntimeTests` rows plus Testing.md's nonexistent BattleRuntime test directory; removed false reduce-transparency variant claims in apple-design skill pages; fixed UITests README smoke-plan paths and crowned the plan↔registry equality check as the rule; replaced BattleEngine Tests README inventory with stable suite families; pointed boss-difficulty numbers at `EnemyPowerCurve`.
- [x] **W2 — Audit dedup:** three-current-uses restatements removed from 01/10/17; seam enumerations collapsed to Proposals.md links in 08/11/13; audio allowlist owned by 12 with pointers from 03/04; proposal-bar restatement in 13 linked to README policy; self-duplicated routing/threshold text trimmed in 01/08/09/17.
- [x] **W3 — Skill trims:** motion quick-reference recap table deleted; SKILL.md completion check + product-override folded into core checklist; materials/accessibility/performance pages defer script-enforced rules to owners.
- [x] **W4 — Package pairs:** deleted pure-pointer AGENTS files (TrinketCore, TrinketTestSupport, TrinketBattleRuntime) and duplicate-content ones (TrinketFeatureSupport hard stop folded into README; TrinketAppState content fully owned by Architecture/cards); Persistence README now links Testing.md's rubric once; BattleFeature README dropped duplicated exclusions and smoke command.
- [x] **W5 — Manifests:** folder-hygiene, committed-generated-files rationale, and `FORCE_ASSET_REENCODE` each stated once in `content-and-manifests.md`; ContentManifest Generate-Catalogs walkthrough replaced by pointer; Art README encode-default prose/memory-threshold duplication trimmed.
- [x] **W6 — DesignSystem/UITests:** export surface kept; enforcement/routing duplication trimmed; UITests keep/drop section removed (Testing.md owns it).
- [x] **W7 — Automation:** `check-docs.py` fails when a `Packages/*/Tests/README.md` names a suite that does not exist (file stems, declared types, or target directories; `*` family patterns skipped).

## Out of scope

- Merging or renumbering audits; restructuring AgentContext cards (routing verified consistent).
- `Identity.md` / `CloudKitPreShipChecklist.md` length: rarely-read product/legal guidance whose detail protects against re-litigating decisions.
- Any script behavior change beyond `check-docs.py`.
- Advancing the `Proposals.md` scope baseline (owned by audit runs).
- Concurrent foreign work in the same tree (BattleEngine correctness pass) — untouched.

## Verification

- `python3 Scripts/check-docs.py` — pass (93 files)
- `./Scripts/test-scripts.sh` — pass (syntax, Python/shell regressions, cache-key alignment, docs)
- Grep sweeps: `adjustedMaterialRewards`, `CardActivationTests`, `TrinketBattleRuntimeTests` have no remaining references
- Isolated path-scoped handoff over touched files only
