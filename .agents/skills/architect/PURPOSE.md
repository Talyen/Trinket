# PURPOSE — architect

## Why this skill exists
Agents repeatedly added public types/methods to `BattleState` or `PlayerSaveStore` instead of the owning handler/engine, widening hub facades.

## Knowledge that motivated it
- [module-dag-containment](../../knowledge/patterns/module-dag-containment.md) — hub containment and DAG enforcement
- [architecture-deferred-seams](../../knowledge/patterns/architecture-deferred-seams.md) — deferred splits stay deferred until a forcing function appears
- `Docs/Platform/Architecture.md` hub table; `check-module-boundaries.sh` as hard gate

## When introduced
2026-08-28 — established persistent knowledge layer; extracted rationale from `Architecture.md` into searchable pattern.
