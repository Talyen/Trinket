# Skill impact log

Prevents re-proposing failed instruction changes. Record only material changes with evidence.

## 2026-08-28 — Establish persistent knowledge layer

Pattern: No durable memory for skill rationale; `.agents/skills/` split across `.agents/` and `Docs/Skills/`; no validated place to test skill changes.

Proposal: Create `.agents/knowledge/` (index + 2 patterns) and `.agents/evals/` scaffold; move `Docs/Skills/apple-design` → `.agents/skills/apple-design`; trim `ios-simulator` skill; add knowledge pointer to `AGENTS.md`; record lifecycle in `knowledge/index.md`.

Result: accepted

Evidence: `AGENTS.md` pre-54 lines, `.agents/skills` ×4, `Docs/Skills/apple-design` ×6, `Scripts/change-classification.sh` routing to `Docs/Skills/apple-design/SKILL.md`, `Docs/AgentContext/README.md` table.

Reason: Separate active guidance (skills), durable reasoning (knowledge), and hard enforcement (types/lint/tests/boundaries) per token-efficiency principles; consolidate to existing `.agents/` convention; keep diff reviewable.

## 2026-08-28 — Refactor AGENTS.md to router + constraints

Pattern: `AGENTS.md` already concise but spent lines on verbose Communication prose.

Proposal: Trim Communication bullets (6→3), compress intro, add 2-line pointer to `.agents/skills/` and `.agents/knowledge/index.md` with “not auto-loaded” instruction.

Result: accepted

Evidence: `AGENTS.md` 54 lines → ~55 lines with knowledge pointer; `Docs/README.md` already owns source-of-truth table.

Reason: Router mental model (`AGENTS.md` = router + universal constraints, skills = active guidance, knowledge = memory, docs = system description, gates = strongest enforcement).

## 2026-09-03 — Surface knowledge in briefing + eval-01 probe pass

Pattern: Knowledge patterns existed but the task briefing never surfaced them; only `architect` linked to memory, the pain log stayed empty, and no eval run was ever recorded.

Proposal: Emit a one-line `Relevant memory` hint from path routing (artwork working-set on pin/cache/hitch paths, DAG containment on manifests/hubs plus every `architect` trigger, deferred seams on `Architecture.md`/CloudKit/split-sensitive paths); print a one-line friction-log nudge in the briefing; link `architect` purpose to deferred seams; cover routing with regression tests.

Result: accepted (probe only; probe discarded, main tree ships routing + docs links, no production combat change)

Evidence: Isolated worktree `eval-probe-01` added `EffectKind.evalProbe`/`Effect.evalProbe` through registry (`TimedDebuffHandler`) + deterministic dispatch test per eval-01; `handoff --isolate` green: style pass, `BattleEngine` 289 passed, `TrinketCore` 39 passed, module boundaries OK, artwork budgets OK. Probe branch removed without merging. Routing spot-checks: prepared-artwork path surfaces artwork lesson, manifest surfaces DAG lesson, `Architecture.md` surfaces DAG + deferred-seams, unrelated smoke path surfaces none.

Reason: Keep memory searchable-not-loaded (near-zero idle cost) while making it discoverable at task time; prove the linked architect guidance still lands a clean, correctly-owned combat change before relying on it.
