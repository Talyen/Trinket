---
name: doc-budget
description: Resolve Swift comment violations or add a necessary checker directive in authored Swift. Use when a task touches comments or a comment gate fails.
---

# Swift comment hygiene

[AGENTS.md](../../../AGENTS.md) owns the no-explanatory-comments rule.
Put durable explanation in the owning documentation; prefer expressive names,
types, and consequential tests for behavior visible in code.

For a necessary toolchain directive or narrow checker exception, inspect the
accepted form in [check-comment-ban.sh](../../../Scripts/check-comment-ban.sh)
and the checker reporting the violation. Keep the reason specific to the site;
an accepted annotation does not authorize bypassing product or safety policy.
Do not copy a transitional exception as a general-purpose comment escape.

Verify changed Swift through the routed style check. The comment checker alone
cannot establish that an exception satisfies the checker whose rule it suppresses.
