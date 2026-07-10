# Dead Code & API Surface Audit

Goal: Remove clearly unused internal symbols and narrow unnecessary APIs without deleting live entry points.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

## Mission

Find one cohesive, high-confidence cleanup. A clean pass is valid. Prefer demoting `public` → `internal` when the API remains useful inside its package.

## Hard stops

- Do not delete symbols referenced from UI tests, manifests, or generated output without regenerating first.
- Prove a candidate is not an app/package entry point, protocol or macro registration, SwiftData/model hook, dynamic lookup, or externally consumed package API.
- Do not hand-edit `Generated/*` — remove unused entries from manifests and run `./Scripts/generate.sh`.
- Do not require Periphery or other new tools; optional if already available.
- Orphaned-test rule is **not** 1:1 file mirroring — support helpers, catalog invariant suites, and ownership-matrix tests are valid without a twin production file.
- Absolute “zero dead exports” is **not** the gate; high-confidence unused is.
- `Packages/TrinketTestSupport/` fixtures are intentionally unused by product code — do not delete them for lacking app call sites.

## Probes

```bash
./Scripts/lint.sh 2>&1 | rg -i 'unused|dead' || true

# Public API candidates in packages — manually verify call sites outside declaring file
rg -n '^public (func|struct|class|enum|actor|protocol|typealias)' \
  --type swift Packages/*/Sources -g '!**/Generated/*' | head -80

# App-target candidates — verify every candidate with references and registrations
rg -n '^(final )?class |^struct |^enum |^actor ' --type swift Trinket/ \
  -g '!*Tests*' -g '!*UITests*' | head -80

# Empty or stub unit/package test files (Swift Testing)
rg -L '@Test|#expect' --type swift TrinketTests Packages/*/Tests || true

# Empty UI test files (XCTest) — separate pass
rg -L 'func test' --type swift TrinketUITests || true
```

SwiftLint unused/dead warnings alone will not catch most dead types — always confirm with `rg` call-site proof.

## Checks

### Exports

- Same-module-only symbols should be `internal` (default)
- Barrel / re-export types need at least one external caller
- Unused generated catalog entries → delete from manifest + regenerate

### Imports

- Remove unused package imports in the app target
- `Models/` / `State/` should not import SwiftUI unless they use SwiftUI types

### Types / files

- Delete source only after reference, registration, generated-output, manifest, UI-test, and package-client checks establish that it is not an entry point
- Inline single-use helpers when it reduces total LOC
- Deleted feature → delete tests, feature folder, and `project.yml` entries, then `./Scripts/generate.sh`

### Tests

- Delete empty / fully commented-out test files
- Remove tests for deleted production code
- Keep intentional cross-cutting suites (invariants, ownership matrix)
- Keep `TrinketTestSupport` fixtures even when product code does not reference them

## Fixes

- Delete or demote with `rg` proof of no callers
- Run `./Scripts/generate.sh` before claiming manifest-generated symbols unused
- Address SwiftLint `unused_import` via `./Scripts/lint.sh`

## Verification

```sh
./Scripts/lint.sh
./Scripts/check-module-boundaries.sh
./Scripts/build.sh          # toolchain permitting
./Scripts/test.sh unit      # if non-trivial deletions; toolchain permitting
```

## Commit

```
chore(<scope>): remove unused <symbol-or-file>

- <what deleted or demoted>
- call-site proof via rg; generate.sh if manifests touched

User-Facing: no
```
