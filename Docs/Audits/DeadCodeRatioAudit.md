# Dead Code Ratio Audit

Goal: Zero dead exports, imports, types, files, and orphaned generated artifacts.

## Targets

- `swiftlint --strict --config .swiftlint.yml 2>&1 | grep -E 'unused|dead'` — catch unused imports and parameters
- Manual review per package `public` API — every public symbol should have at least one call site outside its declaring file
- `rg -c '^import ' --type swift Packages/TrinketContent/Sources/TrinketContent/Generated/` — flag generated files that import nothing or import stale modules
- Verify no orphaned test files: each file in `TrinketTests/` and `Packages/*/Tests/` should map to a production source module

## Checks

### Dead exports in packages

- Every `public` symbol in `Packages/TrinketCore/`, `Packages/TrinketContent/`, `Packages/BattleEngine/`, `Packages/TrinketPersistence/`, `Packages/TrinketDesignSystem/` should be referenced by at least one consumer (another package or the app target)
- Remove `public` from symbols that are only used within the same module — prefer `internal` by default
- Barrel files (`public enum X { }` with no cases, `public typealias` re-exports) — verify each re-export has callers
- Generated catalogs (`ArtCatalog.generated.swift`, `MusicCatalog.generated.swift`, `SFXCatalog.generated.swift`) — if a manifest entry is deleted but the generated code still references it, re-run `./Scripts/generate.sh --assets`

### Dead imports in app target

- Every `import TrinketCore`, `import TrinketContent`, `import BattleEngine`, `import TrinketPersistence`, `import TrinketDesignSystem` should be used — remove unused imports
- `./Scripts/apply-explicit-imports.py` can help bootstrap, but audit should confirm no stray imports remain
- SwiftUI imports in `Models/` and `State/` files — verify the file actually uses SwiftUI types (not just `import SwiftUI` because a neighboring file did)

### Dead types and files

- Any source file that has zero references outside its own module and is not an entry point should be deleted.
- Consider utilizing automated Swift dead code analyzers (such as `Periphery`) or strict Swift compiler unused declarations warnings to detect stale symbols.
- One-use helpers: prefer inlining where it reduces total LOC; do not extract a helper used only once unless it meaningfully improves readability.
- Deleted feature? Delete its test file, its feature folder, and its entry in `project.yml` (then run [generate.sh](file:///Users/ryanmcintire/Documents/Trinket/Scripts/generate.sh))
- Deleted model type? Remove its coded conformance, its test fixtures, and any serialization glue.

### Unused assets and resources

- Audit [Assets.xcassets](file:///Users/ryanmcintire/Documents/Trinket/Trinket/Assets.xcassets) and raw asset resource directories for images, sound effects (`.wav`, `.mp3`), and fonts that are stored in the bundle but never referenced by code.
- If a manifest entry is deleted, ensure the matching resource asset files are cleaned up to control application package/bundle size.

### Generated code drift

- After editing `ContentManifest/`, `ArtManifest/`, `MusicManifest/`, or `SoundManifest/`, run [generate.sh](file:///Users/ryanmcintire/Documents/Trinket/Scripts/generate.sh) to regenerate catalogs.
- If a manifest entry is removed, the regenerated Swift should no longer reference it — if a stale reference remains in non-generated code, remove it.
- [assert-generated-output.sh](file:///Users/ryanmcintire/Documents/Trinket/Scripts/assert-generated-output.sh) (CI gate) catches drift before commit — do not bypass.
- Generated files themselves must not be hand-edited; if a generated symbol is unused, remove it from the manifest, not from the Swift file.

### Orphaned test files

- `TrinketTests/` mirrors app production folders — a test file with no corresponding production source is orphaned.
- `Packages/*/Tests/` mirrors the package source — same rule.
- No test files that only contain `import XCTest` or `import Testing` with no test methods and no test class/suite.
- No test files that are outright commented out; delete them.

### Fixes

- Delete unused exports, types, and files outright
- Inline single-use helpers where inlining reduces total LOC
- Do not delete symbols referenced only from generated files without running `./Scripts/generate.sh --assets` first
- For dead imports: SwiftLint's `unused_import` rule catches most; run `./Scripts/lint.sh` and address
