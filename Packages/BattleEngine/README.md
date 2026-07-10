# BattleEngine

Turn-based card combat simulation for Trinket. Owns `BattleState`, effect handlers, decks/hand, and the player/enemy turn loop.

## Modules

- **BattleEngine** — Core simulation. `BattleState.playCard(cardID:)` and `endTurn()` are the public drivers. Handlers are dispatched through `EffectHandlers.all` and mutate via `BattleEngineContext`.

## Key types

| Type | Role |
|------|------|
| `BattleState` | Mutable simulation state; `playCard` / `endTurn` drive combat |
| `BattleCard` / `BattleHand` / `CombatDeck` | Player ability cards drawn from Hero/Pet loadout decks |
| `BattleCardCombatEngine` | Opening draw, play resolution, enemy turn, end-of-round effect tick |
| `BattleEffectHandler` | Protocol for effect application/tick logic |
| `EffectHandlers` | Registry of all handlers, keyed by `EffectKind` |
| `CombatantRuntime` | Per-combatant runtime state (HP, mana, active effects) |

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

Use `BattleStateTestFactory.makeBattle(...)` with a fixed seed for deterministic outcomes.
