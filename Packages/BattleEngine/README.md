# BattleEngine

Turn-based card combat simulation for Trinket. Owns `BattleState`, effect handlers, decks/hand, and the player/enemy turn loop.

## Modules

Products from `Package.swift`:

- **BattleEngine** — Core simulation library. `BattleState.playCard(cardID:)` and `endTurn()` are the public drivers. Handlers are dispatched through `EffectHandlers.all` and mutate via `BattleState`.
- **BattleBalanceTools** — App-unlinked library for headless simulation, balance policies, sweeps, and reporting (`BattleSimulator`, `BalanceSweepRunner`, contrast runners). Depends on `BattleEngine`; not linked into the Trinket app.
- **BalanceSweepCLI** — Executable entry for bulk sweeps. Depends on `BattleBalanceTools`. Invoke with `./Scripts/balance-sweep.sh`.

## Key types

| Type | Target | Role |
|------|--------|------|
| `BattleState` | BattleEngine | Mutable simulation state; `playCard` / `endTurn` drive combat |
| `BattleCard` / `BattleHand` / `BattleHandBuffer` / `CombatDeck` | BattleEngine | Player ability cards drawn from Hero/Companion loadout decks; overflow waits in a hidden FIFO buffer |
| `BattleCardCombatEngine` | BattleEngine | Opening draw, play resolution, enemy turn, end-of-round effect tick |
| `BattleEffectHandler` | BattleEngine | Protocol for effect application/tick logic |
| `EffectHandlers` | BattleEngine | Registry of all handlers, keyed by `EffectKind` |
| `CombatantRuntime` | BattleEngine | Per-combatant runtime state (HP, mana, active effects) |
| `BattleSimulator` | BattleBalanceTools | Headless autoplay loop for balance sweeps |
| `BalanceSweepRunner` | BattleBalanceTools | Stratified Monte Carlo sweep + markdown reports |

## Hand contract

Visible hand caps at **three** cards (`BattleHand.maxSize`); overflow draws enqueue a hidden FIFO `BattleHandBuffer` and promote after effects / end-turn draws.

Presentation layout (3:4 art, no top chrome, health anchors): [TrinketBattleFeature README](../TrinketBattleFeature/README.md).

## Balance sweep

Manual CLI only — **no CI gates** or scheduled automations.

```sh
./Scripts/balance-sweep.sh --seed 1
./Scripts/balance-sweep.sh --mode ability-contrast --battles-per-tier 200
./Scripts/balance-sweep.sh --mode affix-contrast --tiers middle,lateGame
./Scripts/balance-sweep.sh --mode all --battles-per-tier 1000
```

Writes markdown under `BalanceSweepReports/` (gitignored). Requires a local Swift toolchain (Xcode 26+).
Modes: `identity` (default), `ability-contrast`, `affix-contrast`, `all`.

Locked tooling choices: greedy-v1 autoplay policy; default 100 battles per Early/Mid/Late tier; keyword-aligned gear (generics allowed); catalog identities + scaled level (not journey graph); reproducible seeds.

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

The package command skips `BattleBalanceToolsTests` by default so balance sweeps
do not run in unit or deployment verification. Run those tests only when
explicitly evaluating the balance tools:

```sh
./Scripts/test-package.sh --include-balance-sweep-tests BattleEngine
```

Use `BattleStateTestFactory.makeBattle(...)` with a fixed seed for deterministic outcomes.
