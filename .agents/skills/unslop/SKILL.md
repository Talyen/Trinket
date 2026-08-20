---
name: unslop
description: Change Discipline & AI-Boilerplate Auditor. Auto-triggers post-code generation or when Scripts/change-budget.sh emits surface growth warnings. Strips out speculative extension points, unnecessary guards, forwarding wrappers, and redundant doc comments.
---

# Change Discipline & Unslop Audit

Audit and clean up code diffs against repository Change Discipline standards. Ensure diffs are minimal, maintainable, and free of speculative AI-generated boilerplate.

## Trigger Scenarios

Auto-triggers when:
- Code generation or refactoring edits have been written to disk.
- `./Scripts/change-budget.sh` emits a surface growth warning.
- Adding new files, types, or protocols.

## Execution Steps

1. **Check Surface Budget**:
   - Run `./Scripts/change-budget.sh` to evaluate production and test surface growth.

2. **Inspect Diff for AI Anti-Patterns**:
   - Review active diff (`git diff HEAD`) and check for:
     - **Defensive layers for impossible states**: Unnecessary `guard` statements or `try?` wrappers around known non-nil internal invariants.
     - **Speculative abstractions**: Single-use helper protocols, wrappers, or utility classes instead of extending existing semantic owners.
     - **Forwarding wrappers**: Residual compatibility methods or delegating paths left behind from refactoring.
     - Note: For comment and docstring token hygiene, rely on `doc-budget`.

3. **Validate Code Style & Platform Bans**:
   - Run `./Scripts/check-ui-style.sh`
   - Run `./Scripts/check-platform-api-bans.sh`

4. **Apply Minimal Diff Order**:
   - Follow `AGENTS.md` change hierarchy: `delete → reuse → simplify locally → parameterize duplicate → add abstraction`.
   - Remove unused forwarding paths or single-use abstractions before finalizing.
