# Action, card and Mana contracts

Use with [engine ownership](battle-engine.md) for action identity, hands, preparations or Mana payments.

`CombatantRuntime.talents` groups battle, turn, pending, timed, and action
state explicitly behind copy-on-write storage. Turn start clears only turn state
and expired timed bonuses; pending effects survive until their consuming operation.
Keep an amount and its expiry/source together. The last-action empowerment
receipt retains its existing execution checkpoint.
Next-turn Dodge boosts from Pack Coordination and Smoke Screen live in turn
state so a longer Cleanse bonus cannot extend them.

Playful Energy counts both partners' cards and heals once when the party reaches
its threshold. Feint Strike refreshes one shared next-card bonus; card preparation
reserves it, and only that card's first damaging hit can spend it. A support card
uses the preparation without carrying it forward to another card.
`CombatResolution` owns party preparations and their per-card reservations.
Immediate card damage carries action/card provenance independently of damage
mechanics, including the first pulse of a recurring effect. Later ticks and
reaction damage cannot spend that reservation.

`CombatResolution` owns nested action/card identity, selected outcomes, automatic-play
ancestry, cadence claims, and associated mutable talent action/card bookkeeping.
Do not maintain parallel talent stacks or edit frame arrays from handlers; use its
preparation, consumption, and completion operations. `ResolvedActionFacts` is an immutable shared record:
card reactions, talents, and Uniques read its selected outcome and qualifying
keywords, while talent execution results track what actually happened separately.
Capture facts at preparation; evaluate later operation conditions at their existing
execution checkpoints. Do not classify a played card from `possibleOperations` or
reconstruct its outcome from another talent's bookkeeping. Keep these immutable
records shared so nested actions do not copy their full payload onto the stack.
`BattleActionContext` likewise shares immutable participants while preserving value
equality; payment receipts and checkpoint eligibility retain actor IDs.

`Ability.operations` is the common traversal for classification, empowerment, and
execution; `possibleOperations` includes unresolved outcomes. `BattleActionContext`
binds the selected target for an action and resolves allies/opponents relative to
its actor. A defeated actor cannot continue; a winning card may still resolve its
remaining support rewards. New actions cannot start after battle ends.

`payMana` returns a `ManaPayment` with actual before/after balances. Capture every
contribution to an empowerment purchase before payment reactions; last-Mana rules
read receipts even after refunds or nested actions. Arcane Burst keeps excess
progress across cards and turns separately from cadence claims. Periodic rewards
use `playerTurnNumber` and `isPlayerTurn(every:startingAt:)`; stored `turnCount`
remains zero-based.

## Hand contract

Visible hand caps at **three** cards (`BattleHand.maxSize`); overflow draws enqueue a hidden FIFO buffer in `BattleHand` and promote after effects / end-turn draws. Played cards return to the bottom of that owner’s deck **after** the card’s effects and on-play triggers finish, so a draw during resolve cannot fetch the card still being played.

Pack Tactics deals 3 Physical damage, then draws and plays one card from the
caster's ally's deck. It falls back to the caster's deck when the ally is defeated,
unable to play, or has no card to draw. Other draw-and-play effects retain their
own target and alternating-deck rules.

Unique card returns move the played ability to hand instead of also cycling it
into the deck; turn-start recovery runs before normal draws. Ordinary card plays
own Unique allowances, while automatic abilities and damage repeats cannot
consume them. Full item and interaction rules live in
[Unique equipment](../Product/UniqueItems.md).

Presentation layout (3:4 art, no top chrome, health anchors): [TrinketBattleFeature README](../../Packages/TrinketBattleFeature/README.md).

Turn and opening-hand drivers can record immutable presentation checkpoints while
finishing all engine work synchronously. Incremental draw helpers are package-only.
Operation and mutation contracts live in [battle-engine context](battle-engine.md);
playback and command readiness live in [battle presentation](battle-presentation.md).

`BattleState.assessCard(_:)` provides read-only availability, certain effect
recipients, and resource-use quotes for the battle interaction cues. It shares
affordability, possible outcomes, targeting, and the Mana empowerment budget with
resolution. Assessment never advances RNG or consumes combat preparations.
Automatic-play recipients remain unresolved until their drawn actions execute.
Targets that depend on preceding effects remain unresolved; Panacea exposes
its separate cleanse and healing recipients. Branch-dependent costs and reactive repeated payments remain non-quantitative;
only resolved combat events establish the result. The legacy
`heldCardNextAttackDamage` trigger is retained for saved-item conversion in
`InventoryItem.resolvedPower(at:)`, not as an active combat rule.

For a named talent change, look up its rule in [talent interactions](battle-talents.md).

Use `withAutomaticPlay` for automatic chains; counterattack ancestry follows its
action frame. Do not toggle a separate automatic-play flag.
