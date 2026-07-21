# Inelegant Slop Audit

**Goal:** Find and simplify hotspots of over-engineered, verbose, or un-pragmatic code — especially agent-produced “slop” — without a whole-repo rewrite.

## Intent

Surface a few **confirmed** hotspots via capped size/structure probes. Simplify one cluster so authored LOC, declarations, indirection, or nesting decreases. Moving ceremony among files is not success. Prefer deleting/inlining; significant structural work remains a proposal per [README.md](README.md).

## What “slop” means here

Slop looks industrious but fails a pragmatism test: more types, indirection, comments, or branches than the problem warrants.

| Tell | Why it is slop |
|------|----------------|
| Protocol + single conformer + factory | Indirection with no second implementation |
| `*Manager` / `*Helper` / `*Coordinator` / `*Wrapper` for one function | Noun theater around a free function or method |
| Narrating comments / restated docs | Rephrases the signature instead of encoding non-obvious intent |
| Boolean parameter soup | Combinatorial call sites that should be an enum or two methods |
| Deep nesting / giant `body` / god file | Complexity that should be extracted *or* collapsed, not both layered |
| Pass-through wrappers / rename-only typealiases | Extra names that do not add a boundary |
| Premature DI / config objects for 2–3 fields | Framework cosplay for a local call |
| Defensive `??` / `Result` / `Any` stacks without a real failure mode | Ceremony that hides the real invariant |
| Near-duplicate blocks with tiny diffs | Copy-paste growth instead of one parameterized path |
| Legacy SwiftUI / observation patterns | Fighting the platform baseline in `AGENTS.md` |

Elegant code here is usually: small value types, thin stores, handlers/engines for rules, design-system chrome, exhaustive switches, and direct call sites.

## Hard stops

- Do not collapse intentional seams: battle RNG injection, persistence write coalescing, design-system tokens, catalog/codegen boundaries, or module import rules.
- Do not rewrite battle pipeline math “for clarity” without package tests proving equivalence.
- Do not turn this into a style-only rename sweep, docs rewrite, or mass delete of tests that encode real invariants.
- Prefer the owning audit when the hit is primarily dead code, boundaries, concurrency, type-safety escapes, duplicate feature surfaces, or state-ownership drift.

## Confirm before fixing

1. **Cost:** real reading/editing cost (extra types, deep nesting, duplicated logic, or mixed jobs in one file).
2. **No second need:** one call site / one conformer / no extension point in use.
3. **Safer shape exists:** a shorter local form preserves behavior.
4. **Blast radius:** stay inside the justified cluster; do not expand past related ownership, duplicates, or the shared root cause.

Skip load-bearing complexity (generated catalogs, damage pipeline, save wire format, intentional `@MainActor` lifetime).

## Simplification order

1. **Delete** unused ceremony.
2. **Inline** single-use wrappers.
3. **Collapse** duplicates into one parameterized path in the same module.
4. **Extract** only when a name removes nesting *and* has ≥2 call sites or clear domain meaning.
5. **Move** shared chrome into `TrinketDesignSystem` / rules into the existing owner — never a new layer for one call site.

## Probe hints

- **Over-Nested SwiftUI Bodies:** Search for SwiftUI `body` implementations with indentation depth > 6 levels; extract sub-views or simplify conditional container stacks.
- **Verbose & Redundant Switches:** Search for `switch` blocks in `State/` or `Features/` with identical branch bodies or redundant `default:` fallbacks on frozen enum types.
- **Defensive Double-Unwrapping & Redundant Checks:** Search for `if let x = x, x != nil` or `guard let x = x else { return nil }` wrapping non-optional values or redundant optional checks.
- **Explicit Type Annotation Noise:** Search for explicit type annotations on local variable declarations where Swift type inference is unambiguous (`let name: String = "..."`, `var items: [Item] = [Item]()`).
- **Ceremony Naming & Single-Conformer Protocols:** Search regex `(struct|class|enum)\s+\w*(Manager|Helper|Coordinator|Wrapper|Factory)` and single-conformer `protocol` declarations; inline noun theater.
- **Legacy Observation & Platform API Regressions:** Run `./Scripts/check-platform-api-bans.sh` to catch `@EnvironmentObject`, `@StateObject`, or `#available` regressions.
