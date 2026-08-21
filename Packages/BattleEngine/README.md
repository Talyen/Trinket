# BattleEngine

Turn-based card combat simulation for Trinket. Owns `BattleState`, effect handlers, decks/hand, and the player/enemy turn loop.

## Modules

Products from `Package.swift`:

- **BattleEngine** — Core simulation library. `BattleState.playCard(cardID:)` and `endTurn()` are the public drivers. Handlers are dispatched through `EffectHandlers.all` and mutate via `BattleState`. `GreedyHeuristicPolicy` (`greedy-v1`) picks a playable card for Auto Battle and headless sweeps.
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
| `CombatTriggerEngine` | BattleEngine | Talent and affix combat hooks (`+Damage`, `+Defense`, `+Mana`, `+CardPlay`, `+EnemyTurn`, `+TurnStart`, `+TurnEnd`, `+Cleanse`, `+Resources`, `+Holy`, `+Leech`, `+PartyAuras`) |
| `CombatantRuntime` | BattleEngine | Per-combatant runtime state (HP, mana, active effects) |
| `GreedyHeuristicPolicy` / `SetupAwareHeuristicPolicy` | BattleEngine | greedy-v1 Auto Battle; setup-v1 is sweep-only |
| `BattleSimulator` | BattleBalanceTools | Headless autoplay loop for balance sweeps |
| `BalanceSweepRunner` | BattleBalanceTools | Stratified Monte Carlo sweep + markdown reports |

## Hand contract

Visible hand caps at **three** cards (`BattleHand.maxSize`); overflow draws enqueue a hidden FIFO `BattleHandBuffer` and promote after effects / end-turn draws. Played cards return to the bottom of that owner’s deck **after** the card’s effects and on-play triggers finish, so a draw during resolve cannot fetch the card still being played.

Presentation layout (3:4 art, no top chrome, health anchors): [TrinketBattleFeature README](../TrinketBattleFeature/README.md).

## Balance sweep

Manual CLI only — **no CI gates** or scheduled automations.

```sh
./Scripts/balance-sweep.sh --seed 1
./Scripts/balance-sweep.sh --mode ability-contrast --samples 32
./Scripts/balance-sweep.sh --mode affix-contrast --tiers middle,lateGame
./Scripts/balance-sweep.sh --mode talent-contrast --samples 32 --tiers middle,lateGame
./Scripts/balance-sweep.sh --pacing off --policy setup-v1 --policy-compare
./Scripts/balance-sweep.sh --full-markdown
```

Writes a **findings** markdown brief and a JSON sidecar under `BalanceSweepReports/` (gitignored). Stdout is the findings brief. Successful default runs remove the generated directory after the brief; set `TRINKET_KEEP_REPORTS=1` or `BALANCE_SWEEP_OUTPUT_DIR` when the files must remain. Open the JSON (or pass `--full-markdown` for `*-full.md` tables) only when drilling into a named finding. Requires a local Swift toolchain (Xcode 26+).
Modes: `identity` (default), `ability-contrast`, `affix-contrast`, `talent-contrast`, `mode-progression`, `all`.

`--samples` (default 32) is observations **per identity enemy** and **pairs per contrast focus**, per selected tier. `--battles-per-tier` is a deprecated alias. The CLI never simulates combat in the parent process. It splits work into small chunks (16 identity battles, 8 ability/affix pairs, 4 talent-contrast pair indices, 1 progression run) and runs each chunk in a child process of the same binary. `--jobs` is the process-pool size (default: CPU count). In-process `BalanceSweepRunner` (package tests) still maps work sequentially on the caller thread so it never hops to GCD’s 512 KB stacks. `./Scripts/balance-sweep.sh` builds **release** (`-O`); override with `BALANCE_SWEEP_CONFIGURATION=debug` only for debugging the CLI itself.

Identity spends available talent points (1 per even level) on a legal kit: early a 1-node spend at L4 plus one keyword-aligned basic 1-affix item per combatant (not a full slot fill), middle a partial spend (~10 of 18 nodes at L20) with a full basic kit, late the full 18-node kit. Identity and mode-progression resample party kits until they have at least 3 opponent-damaging cards (or the best of 64 draws); contrast modes still sample independently. Mode-progression Spires are on-level (`floor × 2`); Journey and Labyrinth use earned XP. Spire wins grant equal-level XP at the save level. Ability and affix contrasts keep talents empty. Talent sibling contrasts require a legal point budget for that tier; kit vs none runs only at late. Affix contrasts report empty-slot and replacement-affix baselines for every legal owner. Identity ability/affix/talent tables are within-owner presence margins; use contrasts for causal lifts. Timeouts are excluded from win rate. Progression mode cycles the roster and spends legal talent kits as levels rise.

Locked tooling choices: greedy-v1 Auto Battle and default sweep policy (`setup-v1` is sweep-only); `--pacing on` (default) includes hidden FightPacing; keyword-aligned gear; catalog identities + scaled level (not journey graph); reproducible seeds.

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
