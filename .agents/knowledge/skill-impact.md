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
