# BattleEngine

Turn-based card combat simulation for Trinket. Owns `BattleState`, effect handlers, decks/hand, and the player/enemy turn loop.

## Modules

Products from `Package.swift`:

- **BattleEngine** — Core simulation library. `BattleState.playCard(cardID:)` and `endTurn()` are the public drivers. Handlers are dispatched through `EffectHandlers.all` and mutate via `BattleState`. `PlayPolicy.greedy` (`greedy-v1`) picks a playable card for Auto Battle and headless sweeps.
- **BattleBalanceTools** — App-unlinked library for headless simulation, sweeps, and reporting (`BattleSimulator`, `BalanceSweepRunner`, contrast runners). Depends on `BattleEngine`; not linked into the Trinket app.
- **BalanceSweepCLI** — Executable entry for bulk sweeps. Depends on `BattleBalanceTools`. Invoke with `./Scripts/balance-sweep.sh`.

## Key types

| Type | Target | Role |
|------|--------|------|
| `BattleState` | BattleEngine | Mutable simulation state; `playCard` / `endTurn` drive combat |
| `BattleCard` / `BattleHand` / `BattleHandBuffer` / `CombatDeck` | BattleEngine | Player ability cards drawn from Hero/Companion loadout decks; overflow waits in a hidden FIFO buffer |
| `BattleCardCombatEngine` | BattleEngine | Opening draw, play resolution, enemy turn, end-of-round effect pass |
| `BattleEffectHandler` | BattleEngine | Protocol for effect application and turn-advance logic |
| `EffectHandlers` | BattleEngine | Registry of all handlers, keyed by `EffectKind` |
| `CombatTriggerEngine` | BattleEngine | Talent and affix combat hooks (`+Damage`, `+Defense`, `+Dodge`, `+Block`, `+DoT`, `+Mana`, `+CardPlay`, `+EnemyTurn`, `+TurnStart`, `+TurnEnd`, `+Cleanse`, `+Resources`, `+Holy`, `+Leech`, `+PartyAuras`) |
| `CombatantRuntime` | BattleEngine | Per-combatant runtime state (HP, mana, active effects) |
| `PlayPolicy.greedy` / `.setupAware` | BattleEngine | greedy-v1 Auto Battle; setup-v1 is sweep-only |
| `BattleSimulator` | BattleBalanceTools | Headless autoplay loop for balance sweeps |
| `BalanceSweepRunner` | BattleBalanceTools | Stratified Monte Carlo sweep + markdown reports |
| `BalanceProgressionRunner` / `HotspotAnalyzer` | BattleBalanceTools | Multi-mode journey simulation & difficulty hotspot analysis |

## Hand contract

Visible hand caps at **three** cards (`BattleHand.maxSize`); overflow draws enqueue a hidden FIFO `BattleHandBuffer` and promote after effects / end-turn draws. Played cards return to the bottom of that owner’s deck **after** the card’s effects and on-play triggers finish, so a draw during resolve cannot fetch the card still being played.

Presentation layout (3:4 art, no top chrome, health anchors): [TrinketBattleFeature README](../TrinketBattleFeature/README.md).

## Balance sweep

Manual CLI only — **no CI gates** or scheduled automations. Use the script's
`--help` output for current modes, defaults, and tuning flags.

```sh
./Scripts/balance-sweep.sh --help
./Scripts/balance-sweep.sh --mode ability-contrast
```

The CLI writes a findings brief and JSON sidecar under the gitignored
`BalanceSweepReports/` directory; successful default runs clean them up. Keep
reports only for an active investigation. The runner owns process isolation,
sampling, pacing, policy, and report schemas; this README should not mirror those
defaults. Requires Xcode 26+.

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
