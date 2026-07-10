# BattleEngine

Turn-based card combat simulation for Trinket. Owns `BattleState`, effect handlers, decks/hand, and the player/enemy turn loop.

## Modules

- **BattleEngine** — Core simulation. `BattleState.playCard(cardID:)` and `endTurn()` are the public drivers. Handlers are dispatched through `EffectHandlers.all` and mutate via `BattleEngineContext`.
- **BalanceSweepCLI** — Headless bulk balance sweeps (non-user-facing). See `Docs/Plans/BattleBalanceSimulator.md`.

## Key types

| Type | Role |
|------|------|
| `BattleState` | Mutable simulation state; `playCard` / `endTurn` drive combat |
| `BattleCard` / `BattleHand` / `CombatDeck` | Player ability cards drawn from Hero/Pet loadout decks |
| `BattleCardCombatEngine` | Opening draw, play resolution, enemy turn, end-of-round effect tick |
| `BattleSimulator` | Headless autoplay loop for balance sweeps |
| `BalanceSweepRunner` | Stratified Monte Carlo sweep + markdown reports |
| `BattleEffectHandler` | Protocol for effect application/tick logic |
| `EffectHandlers` | Registry of all handlers, keyed by `EffectKind` |
| `CombatantRuntime` | Per-combatant runtime state (HP, mana, active effects) |

## Balance sweep

```sh
./Scripts/balance-sweep.sh --battles-per-tier 1000 --seed 1
./Scripts/balance-sweep.sh --mode ability-contrast --battles-per-tier 200
./Scripts/balance-sweep.sh --mode affix-contrast --tiers middle,lateGame
./Scripts/balance-sweep.sh --mode all --jobs 8
```

Writes markdown under `BalanceSweepReports/` (gitignored). Requires a local Swift toolchain (Xcode 26+).
Modes: `identity` (default), `ability-contrast`, `affix-contrast`, `all`.

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
