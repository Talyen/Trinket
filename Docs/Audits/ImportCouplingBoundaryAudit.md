# Import Coupling & Boundary Audit

**Goal:** Restore every enforced package and app-layer boundary violation.

## Intent

Run the enforced boundary gate. For each failure, make the ownership-correct repair. A clean gate is valid; do not create abstractions merely to lower import counts. If a gate failure implies misplaced ownership (wrong layer or duplicated owner), prefer a coherent move over a bandaid import — and propose that move when it is a significant refactor per [README.md](README.md).

## Hard stops

- Do not suppress `check-module-boundaries.sh` failures.
- Do not invent new packages to “fix” a cycle without clear ownership in [Architecture.md](../Platform/Architecture.md).
- Generated files are exempt from hand edits.
- Do not invent extra boundary rules beyond Architecture + the gate script.

## Domain rules

Primary gate: `./Scripts/check-module-boundaries.sh` → **0 violations**. The gate is the executable source of truth; package graph and app-layer rules live in Architecture.md. Use explicit imports per package; `./Scripts/apply-explicit-imports.py` may bootstrap imports after a refactor.

**Fixes:** move a shared type to the existing lowest common owner only when ownership is genuinely shared; move presentation code out of a forbidden layer, preserving dependency direction; never disable or weaken the gate. Do not paper over wrong ownership with an import that leaves the type in the forbidden layer.

## Verify

`check-module-boundaries.sh`, `lint.sh`, and `build.sh` if imports changed across targets (toolchain permitting).
