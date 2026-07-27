# Inelegant Slop Audit

**Goal:** Find and simplify hotspots of over-engineered, verbose, or un-pragmatic code — especially agent-produced “slop” — without a whole-repo rewrite.

## Intent

Surface confirmed hotspots so authored LOC, declarations, indirection, or nesting decreases. Moving ceremony among files is not success. Prefer deleting/inlining; significant structural work remains a proposal per [README.md](README.md). A clean pass is valid.

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

## Evidence bar

Real reading/editing cost (extra types, deep nesting, duplicated logic, or mixed jobs), no second need in use, and a shorter local form that preserves behavior. Skip load-bearing complexity (generated catalogs, damage pipeline, save wire format, intentional `@MainActor` lifetime).

## Domain rules

Prefer delete unused ceremony → inline single-use wrappers → collapse duplicates in the same module → extract only when a name removes nesting and has ≥2 call sites or clear domain meaning. Move shared chrome into `TrinketDesignSystem` / rules into the existing owner — never a new layer for one call site. Platform API bans remain enforced by existing gates (`check-platform-api-bans.sh`).
