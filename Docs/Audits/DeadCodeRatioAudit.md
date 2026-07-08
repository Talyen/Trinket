# Dead Code Ratio Audit

Goal: Remove clearly unused internal symbols, demote unnecessary `public` APIs, and delete orphaned files — without deleting live API by mistake.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

## Mission

Find high-confidence dead code. Cap **one cohesive cleanup** (or ≤10 safe deletions). Prefer demoting `public` → `internal` over deleting package API.

## Hard stops

- Do not delete symbols referenced from UI tests, manifests, or generated output without regenerating first.
- Do not hand-edit `Generated/*` — remove unused entries from manifests and run `./Scripts/generate.sh`.
- Do not require Periphery or other new tools; optional if already available.
- Orphaned-test rule is **not** 1:1 file mirroring — support helpers, catalog invariant suites, and ownership-matrix tests are valid without a twin production file.
- Absolute “zero dead exports” is **not** the gate; high-confidence unused is.

## Probes

```bash
./Scripts/lint.sh 2>&1 | rg -i 'unused|dead' || true

# Public API candidates — manually verify call sites outside declaring file
rg -n '^public (func|struct|class|enum|actor|protocol|typealias)' \
  --type swift Packages/*/Sources -g '!**/Generated/*' | head -80

# Empty or stub test files
rg -L '@Test|func test' --type swift TrinketTests Packages/*/Tests || true
```

## Checks

### Exports

- Same-module-only symbols should be `internal` (default)
- Barrel / re-export types need at least one external caller
- Unused generated catalog entries → delete from manifest + regenerate

### Imports

- Remove unused package imports in the app target
- `Models/` / `State/` should not import SwiftUI unless they use SwiftUI types

### Types / files

- Delete source with zero references outside its file when it is not an entry point
- Inline single-use helpers when it reduces total LOC
- Deleted feature → delete tests, feature folder, and `project.yml` entries, then `./Scripts/generate.sh`

### Assets

- After manifest deletions, clean unused bundled assets (size control)
- Never delete assets still referenced by manifests/codegen

### Tests

- Delete empty / fully commented-out test files
- Remove tests for deleted production code
- Keep intentional cross-cutting suites (invariants, ownership matrix)

## Fixes

- Delete or demote with `rg` proof of no callers
- Run `./Scripts/generate.sh` (and `--assets` when needed) before claiming generated symbols unused
- Address SwiftLint `unused_import` via `./Scripts/lint.sh`

## Verification

```sh
./Scripts/lint.sh
./Scripts/check-module-boundaries.sh
./Scripts/build.sh
./Scripts/test.sh unit   # if non-trivial deletions
```

## Commit

```
chore(<scope>): remove unused <symbol-or-file>

- <what deleted or demoted>
- call-site proof via rg; generate.sh if manifests touched

User-Facing: no
```
