# BattleEngine

Turn-based card combat simulation for Trinket. Owns `BattleState`, effect handlers, decks/hand, and the player/enemy turn loop.

## Modules

Products from `Package.swift`:

- **BattleEngine** — Core simulation library. `BattleState.playCard(cardID:)` and `endTurn()` are the public drivers. Handlers are dispatched through `EffectHandlers.all` and mutate via `BattleState`. `PlayPolicy.greedy` (`greedy-v1`) picks a playable card for Auto Battle and headless sweeps.
- **BattleBalanceTools** — App-unlinked library for headless simulation, sweeps, and reporting (`BattleSimulator`, `BalanceSweepRunner`, contrast runners). Depends on `BattleEngine`; not linked into the Trinket app.
- **BalanceSweepCLI** — Executable entry for bulk sweeps. Depends on `BattleBalanceTools`. Invoke with `./Scripts/balance-sweep.sh`.

Combat trigger cadence files live in `Sources/BattleEngine/Triggers/`; damage
resolution files live in `Sources/BattleEngine/Damage/`. Effect handlers remain
in `Sources/BattleEngine/EffectHandlers/`. These folders belong to the same target.

## Key types

| Type | Target | Role |
|------|--------|------|
| `BattleState` | BattleEngine | Mutable simulation state; `playCard` / `endTurn` drive combat |
| `BattleCard` / `BattleHand` / `CombatDeck` | BattleEngine | Player ability cards drawn from Hero/Companion loadout decks; overflow waits in hand buffer |
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

Visible hand caps at **three** cards (`BattleHand.maxSize`); overflow draws enqueue a hidden FIFO buffer in `BattleHand` and promote after effects / end-turn draws. Played cards return to the bottom of that owner’s deck **after** the card’s effects and on-play triggers finish, so a draw during resolve cannot fetch the card still being played.

Unique card returns move the played ability to hand instead of also cycling it
into the deck; turn-start recovery runs before normal draws. Ordinary card plays
own Unique allowances, while automatic abilities and damage repeats cannot
consume them. Full item and interaction rules live in
[Unique equipment](../../Docs/Product/UniqueItems.md).

Presentation layout (3:4 art, no top chrome, health anchors): [TrinketBattleFeature README](../TrinketBattleFeature/README.md).

## Balance sweep

Manual CLI only — **no CI gates** or scheduled automations. Use the script's
`--help` output for current modes, defaults, and tuning flags.

```sh
./Scripts/balance-sweep.sh --help
./Scripts/balance-sweep.sh --mode ability-contrast
```

The CLI writes a findings brief and JSON sidecar under the gitignored
`BalanceSweepReports/` directory. Runs retain reports for comparison; remove
completed investigation artifacts explicitly when they are no longer needed. The runner owns process isolation,
sampling, pacing, policy, and report schemas; this README should not mirror those
defaults. Requires Xcode 26+.

### Reading sweep evidence

Identity runs use the same rotating Hero/Companion schedule for every enemy.
Within a complete Hero × Companion cycle every pairing is represented. Enemy
seeds use the enemy ID, so narrowing an enemy filter preserves that enemy's
samples. This sampling revision changes results from older sweeps with the same
seed; compare reports produced by the same tooling revision.

Win rates and contrast HP/round deltas exclude unfinished battles. Duration
averages include observed rounds up to the cap; they are lower bounds for
unfinished fights. A capped fight cannot count as short, but can count as long
once it exceeds the duration target. Identity findings name enemies with stalls;
contrast findings flag either side when its stall rate reaches the configured
duration flag rate and the minimum pair count. Stalls need investigation even
when the decided battles look healthy.

Affix contrasts remove or replace only the focused affix, preserving other
affixes and their rolled powers on the compared item and all shared gear.

Presence tables count an item or affix once per owner per battle, regardless of
how many equipped slots carry it. These are associations; use the paired ability,
talent, and affix modes to isolate changes. Pairing outliers can appear even when
neither partner is individually unusual. Flags are investigation candidates,
not proof of causation or a correction for testing many comparisons.

Use `--mode all` to include identity, card, talent, affix, and progression checks;
identity alone does not test every combination. Early/middle/late are fixed
loadout profiles; early affix contrasts use one starter item per party member. A lack of flags
with sparse samples or omitted modes does not establish balance. Increase
`--samples`, confirm across seeds, and use `--policy-compare` to check whether an
identity finding depends on autoplay choices. Durations are battle rounds, not
wall-clock seconds or animation timings.

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
