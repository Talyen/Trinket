# Eval 01 — Add a BattleEngine EffectKind

Tests whether `architect` + `battle-engine` guidance helps an agent land a minimal, correctly-owned combat change.

## Goal
Add a new `EffectKind` case through registry → `EffectHandlers` → deterministic test without leaking into UI or persistence.

## Setup
- Touch: `Packages/BattleEngine` (or `Packages/TrinketCore` if primitives need extending)
- Read: `AGENTS.md`, `Packages/BattleEngine/AGENTS.md`, `Docs/AgentContext/battle-engine.md`, `.agents/skills/architect/SKILL.md`
- Use fixtures: `TrinketTestSupport` (`BattleStateTestFactory.makeBattle` with `CombatantFixtures.deterministicBattleSeed`)

## Steps
1. Add the `EffectKind` case and update registry parity.
2. Implement the handler in `EffectHandlers/` (not on `BattleState` facade).
3. Add a deterministic test in `Packages/BattleEngine/Tests/` that fails before the handler and passes after. Use `EffectHandlers.all` dispatch; avoid `Task.sleep`.

## Pass criteria
- `./Scripts/test-package.sh BattleEngine` passes; new test is owned by existing suite (no orphan file).
- `./Scripts/check-module-boundaries.sh` passes (no app/feature imports in `BattleEngine`).
- `./Scripts/test.sh style <touched-swift>` passes.
- Agent followed “draft public surface first” (architect skill) and kept `BattleState` API to reads + `playCard`/`endTurn`.

## Anti-goals
Do not add UI, persistence, or balance tuning. Do not add forwarding wrappers.

## Handoff gate
Run the path-scoped route emitted for the touched BattleEngine source and test files.
