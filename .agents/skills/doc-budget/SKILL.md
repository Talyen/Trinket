---
name: doc-budget
description: Add or repair checker directives and suppression reasons in authored Swift. Use for toolchain/checker annotations or suppression failures, not ordinary explanatory comments.
---

# Checker directives

[AGENTS.md](../../../AGENTS.md) owns comment guidance. Ordinary rationale comments
do not require this skill or a checker exception.

For a necessary toolchain directive or narrow checker exception, inspect the
checker reporting the violation and its accepted form. Keep the reason specific
to the site; an annotation does not authorize bypassing product or safety policy.
[Agent invariants](../../../Scripts/check-agent-invariants.sh) checks concurrency
rationales and SwiftLint suppression reasons; the owning checker validates other
exceptions. A rationale must explain the actual invariant or synchronization.

Verify changed Swift through the routed style check, including the checker whose
rule is suppressed. A comment alone does not establish that the code is safe.
