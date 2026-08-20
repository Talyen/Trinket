---
name: handoff-verifier
description: Zero-LLM Pre-Handoff Checklist & Gate Verifier. Auto-triggers prior to final task completion. Runs canonical path-scoped handoff verification, checks surface budget, and formats a concise completion summary without extra LLM review overhead.
---

# Zero-LLM Pre-Handoff Checklist & Gate Verifier

Verify path-scoped readiness, surface growth, and toolchain constraints before completing a task, producing a concise, readable handoff summary.

## Trigger Scenarios

Auto-triggers when:
- All implementation and mid-task iterations are complete.
- Preparing the final user response or requested commit.

## Execution Steps

1. **Execute Canonical Path-Scoped Gate**:
   - Run path-scoped isolated verification:
     ```bash
     ./Scripts/handoff.sh --isolate --paths <touched-files...>
     ```

2. **Evaluate Surface Growth Budget**:
   - Check surface growth warnings:
     ```bash
     ./Scripts/change-budget.sh
     ```
   - If warnings surface, prepare concise justification per `AGENTS.md`.

3. **Format Readable Handoff Brief**:
   - Write handoff in domain/game terms (what is true now, what was changed).
   - Report exact verification command, pass/fail/skip status.
   - Do not dump long log output, search results, or git diffs into chat.
