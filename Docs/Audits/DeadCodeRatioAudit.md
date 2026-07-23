# Dead Code & API Surface Audit

**Goal:** Remove clearly unused internal symbols and narrow unnecessary APIs without deleting live entry points.

## Intent

Identify all confirmed unused internal symbols and unnecessary APIs, and write a plan to clean them up (breaking into phases if the scope is large). A clean pass is valid. Prefer demoting `public` → `internal` when the API remains useful inside its package. A successful fix must report authored LOC, declarations, files, or exported API removed; moving the same surface is not dead-code reduction.

## Hard stops

- Do not delete symbols referenced from UI tests, manifests, or generated output without regenerating first.
- Prove a candidate is not an app/package entry point, protocol or macro registration, SwiftData/model hook, dynamic lookup, or externally consumed package API.
- Do not hand-edit `Generated/*` — remove unused entries from manifests and run `./Scripts/generate.sh`.
- Orphaned-test rule is **not** 1:1 file mirroring — support helpers, catalog invariant suites, and ownership-matrix tests are valid without a twin production file.
- Absolute “zero dead exports” is **not** the gate; high-confidence unused is.
- `Packages/TrinketTestSupport/` fixtures are intentionally unused by product code — do not delete them for lacking app call sites.

## Domain rules

- Same-module-only symbols should be `internal` (default); barrel/re-export types need at least one external caller.
- Unused generated catalog entries → delete from manifest + regenerate.
- Delete source only after reference, registration, generated-output, manifest, UI-test, and package-client checks establish it is not an entry point.
- Delete empty / fully commented-out test files; keep intentional cross-cutting suites.
- Confirm every candidate with `rg` call-site proof — SwiftLint unused warnings alone will not catch most dead types.

## Probe hints

- **Unreferenced Types & Views:** Search for `struct `, `class `, or `enum ` declarations across `Trinket/Features/` and `Shared/`; perform `rg` call-site verification to find orphaned view components or models.
- **Unused Enum Cases & Switch Branches:** Search domain enums in `BattleEngine` and `TrinketContent` for enum cases with zero construction or pattern-match references.
- **Unread View State & Bindings:** Search for `@State private var`, `@Binding var`, or `@State var` in SwiftUI views that are written to but never read in `body` or logic methods.
- **Uncalled Private/Internal Helpers:** Search for `private func` or `internal func` in large extensions (`AppState+*.swift`, `BattleSession+*.swift`, `VisualFoundation.swift`) that have zero call sites within their module.
- **Package `public` Surface Demotion:** Search `Packages/*/Sources` for `public` structs, enums, or methods that are only consumed within their parent package, demoting them to `internal`.
- **Empty / Stub Test Files:** Search for test files containing zero `@Test` cases or commented-out test bodies.
