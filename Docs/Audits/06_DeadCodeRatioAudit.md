# 06. Dead Code & API Surface Audit

**Goal:** Remove clearly unused authored source, resources, configuration, fixtures, dependencies, and generated inputs, and narrow unnecessary APIs without deleting live entry points.

## Intent

Remove confirmed unused internal symbols, unreachable constant-gated paths, unnecessary APIs, and dead authored support surface. Prefer demoting `public` → `internal` when the API remains useful inside its package. Once an unused root is confirmed, remove its dead dependency cone across source, tests, resources, configuration, manifests, generated inputs, and documentation. A successful fix must report authored LOC, declarations, files, resources, dependencies, configuration, or exported API removed; moving the same surface is not dead-code reduction.

## Hard stops

- Do not delete symbols referenced from UI tests, manifests, or generated output without regenerating first.
- Prove a candidate is not an app/package entry point, protocol or macro registration, SwiftData/model hook, dynamic lookup, or externally consumed package API.
- Do not hand-edit `Generated/*` — remove unused entries from manifests and regenerate.
- Orphaned-test rule is **not** 1:1 file mirroring — support helpers, catalog invariant suites, and ownership-matrix tests are valid without a twin production file.
- Absolute “zero dead exports” is **not** the gate; high-confidence unused is.
- `Packages/TrinketTestSupport/` fixtures are intentionally unused by product code — do not delete them for lacking app call sites.

## Evidence bar

No live consumers across app, tests, manifests, generated output, registration/dynamic hooks, resources, authored configuration, documentation-defined tooling entry points, or package clients; or a branch is provably unreachable under every shipping configuration. Delete source only after those checks establish it is not an entry point.

## Domain rules

- Same-module-only symbols should be `internal` (default); barrel/re-export types need at least one external caller.
- Unused generated catalog entries → delete from manifest + regenerate.
- Unused resources, configuration keys, feature flags, package dependencies, and test fixtures → remove the authored declaration plus registrations, references, generated inputs/output, and stale documentation in the same bounded fix.
- Delete empty / fully commented-out test files; keep intentional cross-cutting suites.

## Example signals

Unused types/views, enum cases with no construction or matches, unread view state, uncalled private helpers, package `public` used only inside the package, permanently disabled branches, unused asset/resource names or configuration keys, redundant dependencies, orphaned fixtures, empty or stub test files.
