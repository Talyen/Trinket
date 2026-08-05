# 11. Inelegant Slop Audit

**Goal:** Find and simplify confirmed hotspots and repeated module-level patterns of over-engineered, verbose, or un-pragmatic code — especially agent-produced “slop” — without an unbounded rewrite.

## Intent

Surface confirmed hotspots so authored LOC, declarations, indirection, or nesting decreases. Once a pattern is confirmed, inventory materially similar instances in the same module or owner and simplify the cohesive cluster when verification remains bounded. Moving ceremony among files is not success. Prefer deleting/inlining; bounded multi-file simplification within the existing owner may ship, while approval-sensitive structural work follows [README.md](README.md). A clean pass is valid.

## What “slop” means here

Slop looks industrious but fails a pragmatism test: more types, indirection, comments, or branches than the problem warrants.

| Tell | Why it is slop |
|------|----------------|
| Protocol + single conformer + factory | Indirection with no second implementation |
| `*Manager` / `*Helper` / `*Coordinator` / `*Wrapper` for one function | Noun theater around a free function or method |
| Narrating comments / restated docs | Rephrases the signature instead of encoding non-obvious intent |
| Boolean parameter soup | Combinatorial call sites that should be an enum or two methods |
| Deep nesting / giant `body` / god file | Ceremony/indirection inside an otherwise right-sized owner; prefer AuthoredMassGrowth when the primary cost is absolute size / mixed jobs with correct ownership |
| Pass-through wrappers / rename-only typealiases | Extra names that do not add a boundary — only when there is no surviving twin path; otherwise DualPathRetention |
| Premature DI / config objects for 2–3 fields | Framework cosplay for a local call |
| Defensive `??` / `Result` / `Any` stacks without a real failure mode | Ceremony that hides the real invariant |
| Near-duplicate blocks with tiny diffs | Copy-paste growth instead of one parameterized path |
| Legacy SwiftUI / observation patterns | Fighting the platform baseline in `AGENTS.md` |

Elegant code here is usually: small value types, thin stores, handlers/engines for rules, design-system chrome, exhaustive switches, and direct call sites.

## Hard stops

- Do not collapse intentional seams: battle RNG injection, persistence write coalescing, design-system tokens, catalog/codegen boundaries, or module import rules.
- Do not rewrite battle pipeline math “for clarity” without package tests proving equivalence.
- Do not turn this into a style-only rename sweep, docs rewrite, or mass delete of tests that encode real invariants.
- Prefer the owning audit when the ceremony has a surviving twin path (DualPathRetention) or the primary cost is absolute size with correct ownership (AuthoredMassGrowth). Full routing: [README.md](README.md) confusable pairs.

## Evidence bar

Real reading/editing cost (extra types, deep nesting, duplicated logic, or mixed jobs), no second need in use, and a shorter form within the existing owner that preserves behavior. Evidence may confirm one hotspot or a repeated pattern cluster; each included instance must share the same cause. Skip load-bearing complexity (generated catalogs, damage pipeline, save wire format, intentional `@MainActor` lifetime).

## Domain rules

Prefer delete unused ceremony → inline single-use wrappers → collapse the confirmed duplicate/configuration/branch cluster in the same owner → extract only when a name removes nesting and has ≥2 call sites or clear domain meaning. Remove obsolete supporting tests and configuration with the replaced ceremony. Move shared chrome into `TrinketDesignSystem` / rules into the existing owner — never a new layer for one call site. Platform API bans remain enforced by existing gates (`check-platform-api-bans.sh`).
