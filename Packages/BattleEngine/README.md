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

`BattleState.assessCard(_:)` provides read-only availability, certain effect
recipients, and resource-use quotes for the battle interaction cues. It shares
affordability, eligible outcomes, targeting, and the Mana empowerment budget with
resolution. Assessment never advances RNG or consumes combat preparations.
Targets that depend on preceding effects remain unresolved; Panacea exposes
its separate cleanse and healing recipients. Branch-dependent costs and reactive repeated payments remain non-quantitative;
only resolved combat events establish the result. The legacy
`heldCardNextAttackDamage` trigger is retained for saved-item conversion in
`InventoryItem.resolvedPower(at:)`, not as an active combat rule.

## Talent interactions

Authored talents and their short descriptions live in
[the talent manifest](../../ContentManifest/talents.tsv). Talent rule changes
reuse the ordinary damage, healing, control, and resource pipelines.

- Damage conversions consume their stored effect before resolving the bonus.
  Noxious Reaction spends Poison up to actual Bleed Health damage without
  reapplying it. Serrated Blades ticks existing Bleeds with their original
  owners and durations; it does not apply another Bleed for each tick. Blood
  Money rewards its owner's lethal hit against a Bleeding enemy, including
  lethal Bleed detonations, instead of rewarding each damage event.
  Turn effects read and commit live state, so later ticks use only the
  remaining potency after earlier decay and consumption.
- Mana Cocoon, Arcane Cleansing, and Chaos Rift use each actual Mana payment.
  Arcane Cleansing removes potency from a randomly chosen present Burn or
  Poison effect, without firing Cleanse or natural-expiry reactions. Chaos
  Rift divides the payment between two distinct elements from its existing
  Freeze, Burn, Poison, and Holy pool; the first receives any odd remainder.
- Steam Explosion consumes Burn during Freeze-card preparation and adds its
  potency to the card's Freeze damage; secondary Freeze reactions do not
  activate it. Backdraft consumes Burn on a critical attack and adds its
  potency after the Critical Hit multiplier, before defenses, in that hit's
  element. Neither conversion detonates Burn or creates another attack.
- Elemental Leech uses the standard Leech rate, including damage-over-time
  ticks; it does not add a second base Leech contribution to an already-Leeching
  hit. Overhealing keeps its emitted reactions even when no Health is restored.
- Living Archive stores half the resolved card healing on the original
  recipient until the next party turn. Echoes do not reroll Critical Hits,
  reapply healing magnitude bonuses, create further echoes, or revive defeated
  recipients. Wishspring uses the original overhealing amount alongside existing
  Block and maximum-Health conversions. Marrowmend fills existing Block only to 6.
- Lesson Learned protects each cleansed keyword until the next party turn.
  Protection prevents reapplication, not the associated damaging hit. Undying
  Ember replaces incoming Burn damage with healing during Death’s Door before
  Dodge or Block; existing Burn still decays normally.
- Dragon’s Patronage uses the card owner’s Mana first, then the living patron’s
  Mana, then any existing Block-for-Mana substitution. Spending reactions belong
  to each actual payer. Prismatic Scales empowers existing Burn and Freeze
  damage and supplies a missing element as a damaging hit, charging Mana once.
- Block theft transfers only available Block without multiplying the amount.
  Light-Fingered uses combat Gold gains, matching the engine’s existing Gold
  theft representation. Sealed Sarcophagus protects Block from theft and Purge,
  while damage, decay, and voluntary spending remain available. Stolen Thunder
  spends Block once per attack; Resonant Shell consumes Thorns normally and
  resolves their damage as Stun with normal buildup.
- Next-card preparations are captured before a card resolves, refresh instead
  of accumulating, and cannot be consumed by the card that created them, even
  when it repeats. Typed damage bonuses strengthen an existing unconditional hit
  of that type when present, avoiding duplicate equipment bonuses. Gilded Claws
  instead accumulates actual Gold stolen until the next attack. Authored
  `Ability.stealsGold` identifies theft from Steal,
  Bounty Shot, Blackjack, and Tithe, and survives outcome resolution and empowerment.
- Sleight of Coin rolls the owner's Critical Hit chance once per Gold card and
  doubles its resolved Gold gains, including theft; these are not attack
  Critical Hits. Full House carries its set of card types across turns, clears
  the set on payout, and does not bank repeated types.
- Interdict prevents reapplication of the buff kinds actually Purged until the
  next party turn, including Block but excluding instant healing and resources.
  Blinding Light retains the strongest half-Holy-hit reduction, counting Health
  damage and absorbed Block, and spends it across the next enemy attack's hits;
  ongoing damage does not consume it. Subzero Mist grants Dodge when the enemy
  recovers from Freeze and expires at the next party turn.
- Shelter Seed checks Health before healing and grants only actual restoration
  as Thorns. Masterwork Mixture transfers resolved card overhealing only into
  the other living ally's missing Health, without rerolling bonuses or bouncing
  back. Thorn Shedding consumes Companion Thorns as Poison damage with normal
  Poison application; the Companion's own Resonant Shell conversion takes
  precedence when both are present.

Trigger and per-combatant talent storage retain value semantics through copy-on-write. Read accessors
borrow stored fields instead of copying the complete trigger set onto the stack;
this matters when attacks resolve nested companion actions.

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

Talent contrasts include every authored row. A focused node is compared with
its sibling when present, or with the same prerequisite build without that node
for a single-node row. Reordered nodes use their current positions for legality;
tiers without enough talent points are skipped rather than given illegal builds.

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
