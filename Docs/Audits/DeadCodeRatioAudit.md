# Dead Code & API Surface Audit

**Goal:** Remove clearly unused internal symbols and narrow unnecessary APIs without deleting live entry points.

## Intent

Find one cohesive, high-confidence cleanup. A clean pass is valid. Prefer demoting `public` → `internal` when the API remains useful inside its package. If many unused symbols share one dead surface or misplaced API layer, prefer that cohesive cleanup — and propose when significant per [README.md](README.md).

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

Lint unused/dead warnings; `public` API in package Sources; empty/stub unit or UI test files (no `@Test` / `#expect` / `func test`).

## Verify

`lint.sh` + boundaries + `build.sh` (toolchain permitting); `test.sh unit` if non-trivial deletions; `generate.sh` if manifests touched.
