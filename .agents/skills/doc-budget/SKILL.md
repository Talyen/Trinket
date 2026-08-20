---
name: doc-budget
description: Comment & AI-Bloat Pruner. Auto-triggers post-edit alongside unslop when Swift files are modified. Strips out self-evident docstrings, parameter echoes, and redundant inline comments to save context tokens and keep code lean.
---

# Comment & AI-Bloat Pruner (Token Saver)

Keep code lean, maintainable, and token-efficient by stripping out self-evident comments, AI chatter, and docstring bloat.

## Trigger Scenarios

Auto-triggers when:
- Authoring or modifying `.swift` files with inline documentation or comments.
- Reviewing diffs for comment token density prior to handoff.

## Execution Steps

1. **Audit Docstrings for Low-Value Redundancy**:
   - Strip docstrings that restate standard Swift signatures (e.g. `/// Initializes the BattleEngine` on `init()`).
   - Remove parameter-by-parameter doc comments (`/// - Parameter name: The name`) when names are self-explanatory.

2. **Eliminate Inline Implementation Chatter**:
   - Delete inline comments that summarize self-evident Swift or SwiftUI code (e.g. `// Create a VStack`, `// Return true`).
   - Keep comments ONLY for subtle business rules, balance rationale, non-obvious algorithms, or safety invariants.

3. **Verify Context Token Hygiene**:
   - Ensure header comments, placeholder boilerplate, and redundant file metadata are removed.
   - Maintain high information density: clear type and symbol naming is preferred over explanatory comments.
