# BattleEngine

Combat simulation for Trinket. Owns `BattleState`, effect handlers, and the turn loop.

## Modules

- **BattleEngine** — Core simulation. `BattleState.advanceOneStep()` is the single entry point. Handlers are dispatched through `EffectHandlers.all` and mutate via `BattleEngineContext`.
- **BattleBalanceTools** — Balance analysis helpers and sweep infrastructure.
- **BalanceSweepCLI** — CLI for parameter sweeps.

## Key types

| Type | Role |
|------|------|
| `BattleState` | Mutable simulation state; call `advanceOneStep()` per tick |
| `BattleSimulator` | Runs a battle to completion (used by tests and previews) |
| `BattleEffectHandler` | Protocol for effect application/tick logic |
| `EffectHandlers` | Registry of all handlers, keyed by `EffectKind` |
| `CombatantRuntime` | Per-combatant runtime state (mana, active effects, cooldowns) |

## Adding a new effect

1. Add the `EffectKind` case (in `TrinketCore`)
2. Create a handler conforming to `BattleEffectHandler`
3. Register it in `EffectHandlers.all`
4. Add registry parity + apply tests

See `Tests/README.md` for test ownership and conventions.

## Testing

```sh
./Scripts/test-package.sh BattleEngine
```

Golden path tests use `BattleStateTestFactory.makeBattle(...)` with `rngSeed: 0` for deterministic outcomes.
