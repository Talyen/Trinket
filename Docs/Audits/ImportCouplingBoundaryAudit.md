# Import Coupling & Boundary Audit

Goal: Restore every enforced package and app-layer boundary violation.

Re-runnable one-shot guide. See [README.md](README.md). Do **not** append findings to this file.

## Mission

Run the enforced boundary gate. For each failure, make the smallest ownership-preserving repair. A clean gate is a valid result; do not create abstractions merely to lower import counts.

## Hard stops

- Do not suppress `check-module-boundaries.sh` failures.
- Do not invent new packages to “fix” a cycle without clear ownership in `Docs/Platform/Architecture.md`.
- Generated files are exempt from hand edits.
- Do not invent extra boundary rules beyond Architecture + the gate script.

## Primary gate

```sh
./Scripts/check-module-boundaries.sh
```

Target: **0 violations**.

The gate script is the executable source of truth. The package graph and app-layer rules are in [Architecture.md](../Platform/Architecture.md). Use explicit imports per package; `./Scripts/apply-explicit-imports.py` may bootstrap imports after a refactor.

## Fixes

- Move a shared type to the existing lowest common owner only when its ownership is genuinely shared
- Move presentation code out of a forbidden layer, preserving the existing dependency direction
- Fix the violation; never disable or weaken the gate

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
