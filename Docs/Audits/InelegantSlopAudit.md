# Inelegant Slop Audit

**Goal:** Find and simplify hotspots of over-engineered, verbose, or un-pragmatic code — especially agent-produced “slop” — without a whole-repo rewrite.

**Siblings:** dead symbols → [DeadCodeRatioAudit.md](DeadCodeRatioAudit.md); boundaries → [ImportCouplingBoundaryAudit.md](ImportCouplingBoundaryAudit.md); custom UI chrome → [AppleNativeUIAudit.md](AppleNativeUIAudit.md); copy-paste screens → [DuplicateFeatureSurfaceAudit.md](DuplicateFeatureSurfaceAudit.md); misplaced hub logic → [StateGravityOwnershipAudit.md](StateGravityOwnershipAudit.md); correctness bugs → [BugHuntingAudit.md](BugHuntingAudit.md).

## Intent

Surface a small set of **confirmed** inelegant hotspots via size, structure, and pattern signals. Simplify one cohesive cluster so the result is shorter and clearer — without changing player-facing behavior unless the verbosity itself is the bug. Prefer deleting ceremony over inventing a new abstraction. When micro-inlines would leave a god file or duplicated pattern intact, prefer a cohesive-area refactor — and propose it when significant per [README.md](README.md).

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

- Do not change player-facing behavior, balance, copy, layout, or `accessibilityIdentifier` values unless removing dead UI.
- Do not “simplify” by introducing a new package, framework, or DI container.
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

Size/density ranking; ceremony names (`Factory`/`Manager`/`Helper`/…); single-conformer protocols; narrating doc comments; near-duplicate switches; banned observation/`#available`/`AnyView` regressions. Route design-chrome duplication through [AppleNativeUIAudit.md](AppleNativeUIAudit.md).

## Verify

Focused package/unit/smoke for the touched area per `AGENTS.md`; always `lint.sh` + `check-module-boundaries.sh`. Design-system chrome moves also need `check-ui-style.sh`.
