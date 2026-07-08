# Import Coupling & Boundary Audit

Goal: Zero package/layer boundary violations; keep import fan-out understandable.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

## Mission

Enforce the module graph and app-layer import rules. Fix all boundary violations found; optionally note high import-count smells (do not churn files solely to hit a numeric quota).

## Hard stops

- Do not suppress `check-module-boundaries.sh` failures.
- Do not invent new packages to “fix” a cycle without clear ownership in `Docs/Architecture.md`.
- Generated files are exempt from hand edits.
- Do not invent extra boundary rules beyond Architecture + the gate script.

## Primary gate

```sh
./Scripts/check-module-boundaries.sh
```

Target: **0 violations**.

What the script currently enforces (keep this list in sync if the script gains checks):

| Rule | Enforced path |
|------|----------------|
| `BattleShell/` must not reference `Features/` | `Trinket/BattleShell` |
| `State/` must not reference `Features/` | `Trinket/State` |
| Packages must not `import Trinket` | `Packages/**` |
| `TrinketDesignSystem` must not import Content / BattleEngine / Persistence | `Packages/TrinketDesignSystem/Sources` |
| `BattleEngine` ⟂ `TrinketPersistence` | each package’s `Sources` |

## Package graph

From [Architecture.md](../Architecture.md) (SoT — diagram is a sketch):

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
       └────Trinket app
```

- `BattleEngine` ⟂ `TrinketPersistence`
- `TrinketDesignSystem` → `TrinketCore` only
- Packages must not import `Trinket` app code or feature views

## App layers

| Layer | May import | Must not import |
|-------|------------|-----------------|
| `BattleShell/` | packages, `Models/` | `Features/` |
| `Features/` | packages, `State/`, `Shared/`, `Models/` | — |
| `State/` | packages, `Models/` | feature views |
| `Models/` | packages, SwiftUI | `State/`, `Features/` |

Use explicit `import` per package. `./Scripts/apply-explicit-imports.py` can bootstrap after refactors.

## Optional smell (not a hard fail)

```bash
rg -c '^import ' --type swift -g '!*Tests*' -g '!**/Generated/*' \
  | awk -F: '$2 > 25 {print}' | sort -t: -k2 -rn
```

Treat >25 imports as a candidate only when a **second signal** exists (god file, high churn, unclear ownership). Do not churn files solely to lower the count.

## Fixes

- Break cycles by extracting shared types into the lowest common ancestor (`TrinketCore`)
- Reduce fan-out with a facade in the owning module when it clarifies the API
- Fix the import — do not disable the boundary script

## Verification

```sh
./Scripts/check-module-boundaries.sh
./Scripts/lint.sh
./Scripts/build.sh   # if imports changed across targets; toolchain permitting
```

## Commit

```
fix(<scope>): restore <layer> import boundary

- <violation fixed>
- check-module-boundaries.sh clean

User-Facing: no
```
