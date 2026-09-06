# 15. Type Safety Audit

**Goal:** Repair unsafe conversions and representations that allow reachable invalid
domain state without replacing valid invariants with meaningless fallback values.

Use the [shared audit contract](README.md) for scope, evidence, severity, and sizing.
Focus on authored production source; follow affected decoder and test contracts
when needed to establish or repair the invariant.

## What confirms a finding

Show an input or construction path that can violate a required invariant: unchecked
indexing, lossy conversion, impossible optional combinations, invalid domain IDs,
erased failures, or an unsafe cast/unwrap. A representation's theoretical capacity
for invalid values is not enough if an enforced boundary excludes them.

`Any`, a force unwrap, or a hard failure is a candidate, not automatic proof.
Check initialization, validation, and every relevant mutation path. Conversely,
compiler/linter cleanliness does not establish that domain states remain valid.

## Remedy and boundaries

Prefer validation at the existing boundary or a clearer state representation over
repeated caller guards. Migrate affected consumers as one coherent repair, preserving
live serialized identifiers and save compatibility. A stronger source type must not
silently change a wire format. Follow the persistence sanitizer/decoder owner for
untrusted saved data.

Use meaningful failure behavior for recoverable input. Preserve a hard invariant
when its preconditions are established; do not replace it with empty strings, zero
values, or silent defaults solely to remove unsafe-looking syntax.

[Verification](../Platform/Verification.md) owns banned observation/navigation APIs
and suppression rules. Report enforced violations distinctly and resolve them under
that policy; banned syntax is not automatically a critical player-facing defect.

Success is an established invariant and appropriate boundary failure behavior,
verified with source proof and the relevant existing checks. Persistence transaction
outcomes belong to [03](03_BehaviorHardeningAudit.md); concurrent isolation escapes
belong to [14](14_SwiftConcurrencyDataRaceAudit.md).
