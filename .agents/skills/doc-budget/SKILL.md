---
name: doc-budget
description: Add or repair checker directives and suppression reasons in authored Swift. Use for toolchain/checker annotations or suppression failures, not ordinary explanatory comments.
---

# Checker directives

[AGENTS.md](../../../AGENTS.md) covers ordinary comments; this skill is only for
toolchain directives and checker suppressions.

When adding or fixing a directive or narrow suppression, check the owning
checker's accepted format and keep the rationale specific to the site—especially
the actual concurrency invariant or synchronization reason.
[Scripts/check-agent-invariants.sh](../../../Scripts/check-agent-invariants.sh)
validates concurrency rationales and SwiftLint suppression reasons; other
checkers validate their own exceptions. Verify the change through the routed
style check.
