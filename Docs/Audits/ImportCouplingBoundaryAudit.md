# Import Coupling & Boundary Audit

Goal: Zero circular imports; efferent imports per module p90 ≤ 12, max ≤ 20; zero layer-boundary violations.

## Targets

- `./Scripts/check-module-boundaries.sh` — target 0 violations
- `swiftlint --strict --config .swiftlint.yml 2>&1 | grep -i 'import\|boundary'` — flag unexpected cross-layer imports
- Manual `rg '^import ' --type swift` counts per file — flag files with > 20 imports

## Checks

### Package graph violations

Enforce the unified dependency graph from [Architecture.md](../Architecture.md):

```
          TrinketCore
           ▲       ▲
           │       │
    TrinketContent │
       ▲       ▲   │
       │       │   │
  BattleEngine │   TrinketDesignSystem
       │   TrinketPersistence
       │       ▲   │
       │       │   │
       └────Trinket app
```

- `BattleEngine` and `TrinketPersistence` are siblings — they must not import each other.
- `TrinketDesignSystem` depends on `TrinketCore` only — must not import `BattleEngine` or `TrinketContent`.
- Packages must not import `Trinket` app code or SwiftUI feature views.
- No circular imports between packages (`madge`-style check via [check-module-boundaries.sh](../../Scripts/check-module-boundaries.sh)). Ensure this script is integrated into your local git workflow (e.g. pre-push hook).

### App target layer violations

From `Docs/Architecture.md`:

| Layer | May import | Must not import |
|-------|------------|-----------------|
| `BattleShell/` | packages, `Models/` | `Features/` |
| `Features/` | packages, `State/`, `Shared/`, `Models/` | — |
| `State/` | packages, `Models/` | feature views |
| `Models/` | packages, SwiftUI | `State/`, `Features/` |

- Use **explicit** `import` per package — no blanket re-exports
- `./Scripts/apply-explicit-imports.py` can bootstrap after refactors; audit should confirm no hidden transitive imports

### Import count hygiene

- Files exceeding 20 imports likely need a barrel/facade or extraction
- Within `Packages/`, prefer importing the owning module's public API, not transitive dependencies
- Generated files (`Generated/*.swift`) are exempt but changes should propagate through codegen, not manual edits

### Fixes

- Break cycles by inverting the dependency: extract a shared protocol or model into the lowest common ancestor package (`TrinketCore`)
- Reduce efferent coupling by adding a facade file in the owning module
- Do not suppress `check-module-boundaries.sh` failures — fix the import
