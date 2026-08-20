---
name: why
description: Intent & Context Recovery Engine. Auto-triggers when refactoring or modifying core combat rules, balance numbers, state machines, or persistence schemas. Synthesizes Decisions.md, test assertions, git history, and AgentContext docs to recover rationale before changes.
---

# Context & Intent Recovery Engine

Recover historical intent and architectural rationale before modifying established game mechanics, combat state resolution, balance numbers, or persistence logic.

## Trigger Scenarios

Auto-triggers when:
- Refactoring turn engine resolution, card effects, or combat state logic.
- Modifying game balance constants, difficulty curves, or drop rates.
- Altering persistence schemas, CloudKit models, or migration logic.

## Execution Steps

1. **Search Decision & Product Documentation**:
   - Search `Docs/Product/Decisions.md` and `Docs/Product/Identity.md` for matching design records.
   - Check `Docs/Audits/Proposals.md` to ensure the logic isn't a previously rejected or accepted audit item.

2. **Inspect Agent Context Cards**:
   - Run `./Scripts/agent-context.sh --agent --paths <files...>` to view domain-specific guidance cards in `Docs/AgentContext/`.

3. **Check Test Suite Invariants**:
   - Search unit tests for assertions and test case names that reference the logic:
     ```bash
     rg "test.*<FeatureOrSymbol>" Packages/
     ```
   - Test names often document *why* a specific boundary condition or ordering exists.

4. **Query Commit Rationale**:
   - Inspect git history for the relevant lines to review past commit rationale:
     ```bash
     git log -n 5 -L <start>,<end>:<filepath>
     ```

5. **Synthesize Rationale**:
   - Explain the "why" behind existing code before replacing or refactoring it, ensuring business invariants are preserved.
