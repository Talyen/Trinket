# Dead Code & API Surface Audit

**Goal:** Remove clearly unused internal symbols and narrow unnecessary APIs without deleting live entry points.

## Intent

Remove confirmed unused internal symbols and unnecessary APIs. Prefer demoting `public` → `internal` when the API remains useful inside its package. A successful fix must report authored LOC, declarations, files, or exported API removed; moving the same surface is not dead-code reduction. A clean pass is valid. Planning and phasing: [README.md](README.md).

## Hard stops

- Do not delete symbols referenced from UI tests, manifests, or generated output without regenerating first.
- Prove a candidate is not an app/package entry point, protocol or macro registration, SwiftData/model hook, dynamic lookup, or externally consumed package API.
- Do not hand-edit `Generated/*` — remove unused entries from manifests and regenerate.
- Orphaned-test rule is **not** 1:1 file mirroring — support helpers, catalog invariant suites, and ownership-matrix tests are valid without a twin production file.
- Absolute “zero dead exports” is **not** the gate; high-confidence unused is.
- `Packages/TrinketTestSupport/` fixtures are intentionally unused by product code — do not delete them for lacking app call sites.

## Evidence bar

No live consumers across app, tests, manifests, generated output, registration/dynamic hooks, or package clients. Delete source only after those checks establish it is not an entry point.

## Domain rules

- Same-module-only symbols should be `internal` (default); barrel/re-export types need at least one external caller.
- Unused generated catalog entries → delete from manifest + regenerate.
- Delete empty / fully commented-out test files; keep intentional cross-cutting suites.

## Example signals

Unused types/views, enum cases with no construction or matches, unread view state, uncalled private helpers, package `public` used only inside the package, empty or stub test files.
