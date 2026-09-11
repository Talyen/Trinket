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

Enemy abilities resolve offensive effect targets and opponent conditions against
the selected party member. Conditions keep that target throughout the action,
including after earlier hits change the party's Health ordering. Shared keyword
reactions also run for enemy traits, with healing and Block awarded to the source's
side; party-wide talent bonuses remain restricted to the party.

## Key types

| Type | Target | Role |
|------|--------|------|
| `BattleState` | BattleEngine | Mutable simulation state; `playCard` / `endTurn` drive combat |
| `DamageOperation` / `HealingOrigin` | BattleEngine | Explicit operation meaning, independent of logging or recursion depth |
| `BattleActionContext` / `CombatResolution` | BattleEngine | Actor-relative targets, shared selected outcomes, nested action/card identity, and cadence ownership |
| `CombatCheckpoint` / `ManaPayment` | BattleEngine | Reaction continuation rules and immutable payment facts |
| `HealingResult` / `DamageDefensePolicy` | BattleEngine | Healing delivery facts and consistent defense bypass |
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

## Concern guides

[Engine ownership](../../Docs/AgentContext/battle-engine.md) is the common contract.
Read only the matching detail: [hands and actions](../../Docs/AgentContext/battle-actions.md),
[damage and effects](../../Docs/AgentContext/battle-damage.md),
[healing and gains](../../Docs/AgentContext/battle-healing.md),
[named talent interactions](../../Docs/AgentContext/battle-talents.md), or
[balance sweeps and evidence](../../Docs/AgentContext/battle-balance.md).

## Adding a new effect

1. Add the `EffectKind` case (in `TrinketCore`)
2. Create a handler conforming to `BattleEffectHandler`
3. Register it in `EffectHandlers.all`
4. Preserve registry parity and verify apply/expiry behavior through the existing
   handler coverage; extend tests only for consequential gaps under
   [Testing.md](../../Docs/Platform/Testing.md).

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
