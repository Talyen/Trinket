# Action, card and Mana contracts

Use with [engine ownership](battle-engine.md) for action identity, hands, preparations or Mana payments.

## Shared action invariants

`CombatantRuntime.talents` groups battle, turn, pending, and timed
state explicitly behind copy-on-write storage. `CombatResolution` owns action-scoped
empowerment so nested actions restore their parent flags and completed actions cannot
amplify later reactions. Turn start clears only turn state
and expired timed bonuses; pending effects survive until their consuming operation.
Card/action-scoped readied bonuses keep their value and provenance together in
`PreparedTalentBonus`; `consumeTalentPreparation` checks provenance and clears the
whole preparation. `prepareTalentBonus` captures the creating card and, for action-scoped
preparations, its action. Replacement and strongest-value merges refresh that provenance
together; callers keep eligibility checks and the intentionally inherited-provenance cases.
Callers own keyword and operation eligibility. Block bonuses
clear only after a positive base gain. Keep an amount and its expiry/source
together. The owning card retains its empowerment receipt through the Spell Echo checkpoint;
prepared card repeats inherit their parent action's empowerment without another payment.
Next-turn Dodge boosts from Pack Coordination and Smoke Screen live in turn
state so a longer Cleanse bonus cannot extend them.

## Card preparations

Playful Energy counts both partners' cards and heals once when the party reaches
its threshold. Shared next-card Dodge bonuses refresh rather than stack; card preparation
reserves it, and only that card's first damaging hit can spend it. A support card
uses the preparation without carrying it forward to another card.
Whiplash, Wing Buffet, and Counter Pounce arm after the Dodge's Basic counterattack
finishes, including deferred counterattacks; older preparations remain eligible for that counterattack.
`CombatResolution` owns party preparations and their per-card reservations.
Immediate card damage carries action/card provenance independently of damage
mechanics, including the first pulse of a recurring effect. Later ticks and
reaction damage cannot spend that reservation.
The supported `furnaceRhythm` and `temperCycle` repeat preparations belong to the
combatant that played the priming card. Partner cards cannot consume them; End Turn clears them.

## Action identity and selected outcomes

`CombatResolution` owns nested action/card identity, selected outcomes, automatic-play
ancestry, and associated mutable talent action/card bookkeeping. Actions use one
LIFO stack; automatic-play scopes retain a nesting depth rather than placeholder
action frames. Counterattack ancestry also classifies nested feedback as automatic.
Its value-owned
`CombatActivationLedger` partitions claims by cadence: action, card, and standalone
restoration completion release only their own bucket; turn and standalone-action
claims retire the previous cadence on first use. Battle claims survive nested
completion, and copied battle states retain independent activation allowances.
Activation allowances use `CombatActivationClaim` mechanic identities, never
display names or trigger-name lookups. Share a key only for reactions that share
an allowance; retain the claim namespace, actor, and cadence when changing copy.
Do not maintain parallel talent stacks or edit frame arrays from handlers; use its
preparation, consumption, and completion operations. `ResolvedActionFacts` is an immutable shared record:
card reactions, talents, and Uniques read its selected outcome and qualifying
keywords, while talent execution results track what actually happened separately.
Capture facts at preparation; evaluate later operation conditions at their existing
execution checkpoints. Do not classify a played card from unresolved alternatives or
reconstruct its outcome from another talent's bookkeeping. Keep these immutable
records shared so nested actions do not copy their full payload onto the stack.
`BattleActionContext` likewise shares immutable participants while preserving value
equality; payment receipts and checkpoint eligibility retain actor IDs.
Independent passive restoration operations have separate talent-roll allowances;
nested restoration reactions share their parent allowance. Card and action
restoration still use their existing per-card and per-action claims.

Ability definitions share immutable storage so nested automatic casts and combat
snapshots do not copy the complete definition through each stack frame.
`Ability.operations` is the authoritative ordered traversal for classification,
empowerment, descriptions, and execution. Deterministic conditional outcomes resolve
once at action preparation, without RNG, and card assessment uses the same selection
before quoting costs.
Random outcomes remain separate. Branch eligibility is checked before sampling,
and `BattleAbilityRules.possibleOutcomes` supplies the same branches to execution,
assessment and Health-cost quotes without RNG. If no branch qualifies, all authored
branches remain possible under the existing execution fallback; their costs must
still pass affordability. `BattleDamageRules` owns component condition and Block
scaling evaluation for execution and cost quotes, plus component eligibility for
assessment and prepared action facts. Pass the bound action target to these rules.
Evaluate amounts at each operation checkpoint, rather than caching them before
earlier effects and reactions. Health costs require strictly more Health than the
largest possible branch cost.
Blackjack deals 3 Stun damage and evaluates its Stun-conditioned theft after damage:
existing Stun and Stun newly caused by that hit both qualify.
Paid in Full banks one bonus after theft for the next attack of any damage type;
Bounty Blade retains its separate Physical-only bonus. Repeated theft refreshes
these pending bonuses without stacking them; ongoing damage does not consume them.
Luck Potion rolls 1–12 and draws one caster card after its gain. Health outcomes
are excluded when no living ally is injured; healing chooses the lowest current
Health among injured living allies. Conditional guaranteed criticals snapshot their
eligibility at preparation. `BattleActionContext`
binds the selected target for an action and resolves allies/opponents relative to
its actor. A defeated actor cannot continue; a winning card may still resolve its
remaining support rewards. New actions cannot start after battle ends.

## Combat log projection

`ActionEvent.Kind` carries its effect outcome or milestone as an associated value;
there are no independent optional tags to reconcile. Emit each committed result
through `BattleState.nextEvent` with its final meaning. Returned command events
and retained history must agree for the same event ID;
never retag a returned copy of an already emitted reaction.

Engine event emitters require `CombatEventSource`, pairing actor identity with its
display text. Healing and Mana helpers retain that source across redirected gains;
periodic/environmental captions explicitly carry their owner ID or no owner.
Effect handlers supply the actual ability ID before automatic-play origin
classification. Shared gain/removal helpers forward supplied IDs; passive reactions
do not inherit the surrounding card's ID. Floating feedback and
combat sound match automatic card effects by feedback group, actor ID, and ability
ID through `CombatCardSourceKey`, never by display names.

Combat logs summarize committed damage by recipient and keyword, with self-paid
Health costs reported separately. Damage packets and their summary share the
resolved action identity so nested actions do not combine their totals. Packets
precede their summary. `BattleLogProjection` consumes append-only history once,
retaining unmatched packets across updates and releasing them at each summary;
complete replay uses that same projection. Truncated history resets the projection;
same-length replacement requires `rebuildFromScratch`. Named damage without an
ability ID, including unique repeats and boss pulses, logs immediately rather than
waiting for an action summary. Leech logs actual restored Health for its recipient;
unspent healing overflow does not inflate that restoration.
Support-only log summaries do not assign the selected attack target to allied
effects; committed effect events identify their actual recipients. Direct Mana
gain summaries report the actual restoration after capacity limits and bonuses.
Multi-recipient gain summaries saturate their total without reducing individual grants.
Effect percentage text and event amounts use bounded numeric conversion.
Action summaries retain typed applied effects only. Log entries store committed events
and damage totals grouped once by recipient and keyword; their single localized
formatter derives wording when displayed,
without building or retaining a separate English transcript during combat.
Merchant's Favor counts distinct ability IDs from successfully admitted card plays
by its living wearer, including automatic and winning cards. Replays and separate
copies of one ability count once; partner cards and ordinary non-card actions do
not count. Track at most seven identities in that wearer's battle runtime. Victory
pays one base Gold per identity through ordinary Gold modifiers, at most once via
the existing defeat milestone; a new battle starts empty. Saved Merchant's Favor
powers adopt this rule and stop granting turn-start Gold.
Targeted effects can carry a fixed chance, rolled once after their condition passes.
A failed roll grants no resource or gain feedback; preceding card damage still resolves.
Empowerment and talent transformations preserve the chance.
Gold effect summaries use the ability's theft marker and report the actual grant
after equipment and talent bonuses. Golden Plate grants 8 Block, or 12 if its
wearer gained positive Gold during the current turn. Gold from the partner or a
previous turn does not qualify. The condition resolves one Block grant, so
Block-gain bonuses and reactions apply once; Golden Plate never grants or spends Gold.

## Turn ordering

End-of-player-turn talents resolve before the enemy action. Mana Shield's Block
can absorb that action and reads the wearer's current Mana when its step runs,
including restoration from an earlier party member's reactions. End-turn healing
and Cleanse finish before the enemy action begins.
Round effects and passive Block decay follow the enemy action.
Turn cadences recheck battle completion and source survival between operations and
party recipients, including End Turn, Purifying Aura, and Gold/Health regeneration.
A victory during one of these reactions stops the remaining cadence rewards,
including the other party member's ordinary turn-start Mana restoration.
Card completion records its play count even if a completion reaction defeats the
owner; the living partner can still earn a party-wide card-count reward.
A Dodge-triggered automatic card chain rechecks its owner before later Dodge
rewards; defeat during the drawn card cannot grant Tailwind afterward.

## Mana payments and cadence

`payMana` returns a `ManaPayment` with actual before/after balances. Capture every
contribution to an empowerment purchase before payment reactions; last-Mana rules
read receipts even after refunds or nested actions. A prepared empowerment discount
applies to one purchase; Meteor and Falling Star can then buy their normal paid
repeats. A reaction that ends combat stops further empowerment purchases.
Permanently free empowerment remains bounded to one purchase.
Repeated Freeze empowerment includes Winter's Credit's available Block in its
purchase budget, including for a wearer with no Maximum Mana.
The `spendManaThresholdAutoPlayCard` trigger keeps excess Mana-spend progress
across cards and turns separately from cadence claims. Mana Moth's current
[Arcane Burst](battle-talents.md#dark-recovery-and-arcane-burst) instead rolls a
damage multiplier for an empowered action. Periodic rewards
use `playerTurnNumber` and `isPlayerTurn(every:startingAt:)`; stored `turnCount`
remains zero-based.

## Hand contract

Each player turn schedules three ordinary draws, including the opening turn.
Hero–Companion–Hero alternates with Companion–Hero–Companion; effect draws do not
advance this sequence. Each owner starts with one shuffled Basic, Skill, and
Ultimate. A sole living party member receives all scheduled draws; blocked or
empty decks do not borrow the living partner's draw. Cards remain in arrival order.

Visible hand caps at **three** cards (`BattleHand.maxSize`); overflow draws enqueue
a hidden FIFO buffer and promote after effects / end-turn draws. Unplayed cards
survive turn changes. Played physical copies enter their owner's discard pile in
play order, before resolving effects. After the enemy turn and round effects,
discards append behind undrawn cards before new-turn draws. Empty draw piles never
refill mid-turn; decks do not reshuffle after battle start.

Pack Tactics deals Physical damage, then draws a manual card from the caster's
ally's deck. It falls back to the caster's deck when the ally is defeated, blocked
from drawing, or has no card to draw. Health-cost affordability is checked when
the drawn card is played, rather than when it is drawn.
Feint grants +40% Dodge chance until the next turn and draws two manual cards from
the caster's deck; a missing card does not borrow the partner's. Dodge bonuses
are additive and the usual 75% chance cap applies. Shadowstep deals Physical damage, then draws
from the caster's deck, without Dodge or repeat preparation. Current card text
is owned by the [authored ability catalogs](content-and-manifests.md#abilities).

The engine's `playNextCardTwice` effect remains supported but is not granted by
current authored abilities. It repeats the caster's next manually played card,
or an enemy's next normally executed ability.
Partner cards, automatic plays, counterattacks, and echoes preserve that preparation;
skipped or intercepted enemy actions preserve it too. Refreshes do not stack.
Reserve the repeat before effects begin. Resolve the prepared card's effects twice,
including support effects and affordable self-damage, with Block costs and Mana
empowerment paid once. Physical card movement, action cadence, and card-completion
rewards occur once. One-shot hit bonuses retain their ordinary consumption rules.
Repeats cannot consume a freshly readied repeat; an action granting
`playNextCardTwice` leaves that preparation for a later card. Stop repeating after
combat ends, caster defeat, or an unaffordable Health cost. Draw-and-play
effects start with the targeted owner; multi-card requests alternate decks and may
fall back to the other owner, while a single-card request uses only its target.
Draw-and-play collection stops when no candidate can draw;
its work is bounded by available cards rather than the requested count.
Collection checks both Health and Block affordability before drawing a candidate;
an unaffordable card stays in its deck, allowing the multi-card partner fallback.

Card returns preserve the physical copy's identity and create a fresh presentation
ID on arrival, without adding a deck copy. [Unique equipment](../Product/UniqueItems.md#card-cadence-and-reactions)
owns Returning Flight/Gale eligibility, ordering, and reset cadence.

Dance of Blades continues its draw-and-play chain only after the drawn attack
Critically Hits; critical healing or Leech restoration cannot extend it.

Combatant effect details include active talent preparations and readied Unique
powers, including Wrenflight's temporary Dodge and accumulated Golden Crucible
damage, Lesson Learned's protected debuff keywords, and Interdict's blocked buffs.
Entries follow the same consumption and expiry rules as their bonuses.
Full automatic Basic abilities use ordinary attack damage talents such as Razor
Claws, Ground Slam, and Battering Ram; card-only cadences retain their restrictions.

Consolation Prize creates one uniformly random card from `AbilityCatalog.all` on
the owner's first fully Blocked attack per combat. Claim before generation; the
new copy belongs to that owner, respects FIFO overflow, and follows ordinary
cycling for this battle without changing the saved loadout.
Card admission also checks live pending Stun and Freeze, so a generated card cannot
bypass control applied after turn preparation.
Battle preparation pins the possible card artwork only when Consolation Prize is
equipped, preserving
immediate card play without mid-battle on-demand decoding.

Presentation layout (3:4 art, no top chrome, health anchors): [TrinketBattleFeature README](../../Packages/TrinketBattleFeature/README.md).

`BattleTurnState` retains a deferred opening or reserves command resolution.
Card, turn, and opening commands finish all engine work synchronously before
returning events and optional action records; there are no incremental draw or
settlement entry points. `BattlePhase.preparingTurn` rejects manual cards and
End Turn during resolution. Opening settlement consumes its preparation before
applying effects, so retries cannot grant Block, Mana or talent rewards twice.
A caller-supplied hand can replace a deferred opening: the first manual card or
End Turn consumes it without granting its effects later. Party control skips
resolve Hero then Companion, independently of set iteration order.

Operation and mutation contracts live in [battle-engine context](battle-engine.md);
playback and command readiness live in [battle presentation](battle-presentation.md).

## Card assessment

`BattleState.assessCard(_:)` provides read-only availability, certain effect
recipients, and resource-use quotes for the battle interaction cues. It shares
affordability, possible outcomes, targeting, and the Mana empowerment budget with
resolution. Quotes deduct the card’s Block cost before budgeting empowerment, then
combine both Block spends against the original balance. Assessment never advances RNG
or consumes combat preparations.
Chance effects do not promise a recipient unless their chance is guaranteed.
Zero-chance conversions quote no payment; probabilistic conversions retain an
unspecified amount rather than promising to spend the current balance.
Effect application and assessment share composite Aegis constituents, Panacea
recipient rules, and deferred draw-recipient selection through `EffectApplication`.
Mana quotes pass operation keywords and empowerment settings directly to the shared
budget, without constructing synthetic abilities. Repeated-payment certainty keeps
its conservative trigger check; new unmodeled reactions remain non-quantitative.
Random damage elements retain a certain recipient with an unspecified damage
keyword when every outcome damages that recipient. Automatic-play recipients
remain unresolved until their drawn actions execute.
Targets that depend on preceding effects remain unresolved; Panacea exposes
its cleanse recipient, while healing remains unresolved after debuff removal when
multiple allies are alive because Cleanse reactions can change Health. A sole living
ally remains a certain recipient. Branch-dependent costs and reactive repeated payments remain non-quantitative;
this includes last-Mana restoration that can fund another empowerment purchase.
Only resolved combat events establish the result. Mana-to-Block quotes include every living
recipient; conversions after earlier operations or recipient reactions retain an
unspecified amount because the opening balance may have changed. Static discounts such as
Pyromancer’s Spark still allow a quantitative repeated-payment quote. The legacy
`heldCardNextAttackDamage` trigger is retained for saved-item conversion in
`InventoryItem.resolvedPower(at:)`, not as an active combat rule.

## Automatic play

Auto Battle prioritizes a finishing card by resolving one play on a copy of the
current battle, including its RNG. Conditions, scaling, defenses and interrupted
multi-hit actions follow the ordinary engine; the live battle stays unchanged.
A forecast win must leave its card owner alive. Non-finishing choices retain the
policy's heuristic scoring, using eligible outcomes and opening-state conditional/scaled
damage estimates with a self-damage penalty for each branch. Conditional effects
contribute only when their condition holds in that opening state. Integer scores saturate
instead of trapping. Forecasts skip log rebuilding and presentation recording.

`AutoBattleProgress` observes the enemy's committed peak Health depletion, including
damage healed within one command. Thirty rounds without further depletion pauses
automated play; it never changes combat state, outcomes, or rewards. Each explicit
Auto Battle run starts a fresh window. Slow fights can continue beyond thirty rounds
while making progress. Manual commands remain available after a pause.

For a named talent change, look up its rule in [talent interactions](battle-talents.md).

Use `withAutomaticPlay` for automatic chains; counterattack ancestry follows its
action frame. Do not toggle a separate automatic-play flag.

## Ability strategy

Bloodthorn selects one equally likely 3-damage Bleed or Poison hit at preparation;
either result has Leech. It never applies both damage types in one action.
Hit-specific Leech survives damage amplification, keyword resolution and Mana
empowerment. Card-wide Leech retains its existing all-hit rule.

- Avatar reserves its Holy conversion at the next direct attack's first eligible
  hit, before reactions. All direct hits in that action share it; nested attacks
  and recurring damage cannot spend that reservation. A fresh Avatar preparation
  granted during the action survives for the next attack.
- Shield Bash gains 1 Block, then deals Stun damage equal to half the actor's
  current Block, floored and clamped to a minimum of 1. The gain happens before
  the damage calculation and no Block is spent.
- Ice Shot deals 2 Freeze damage, doubled against an already Frozen target.
  It preserves Frozen and remains Freeze damage for empowerment and identity.
- Maul chooses 3 Stun against positive enemy Block or 3 Bleed otherwise; it is
  not random. Stab guarantees a Critical Hit against full Health at preparation
  and otherwise uses ordinary critical chance, without its former +25% bonus.
- Sunder halves Block before its 4 Physical hit, using existing halving rounding.
- Sniff Out deals 1 Bleed damage, then prepares +1 generic damage for the living
  partner, falling back to the caster if the partner is defeated. Reapplication
  refreshes rather than stacks;
  preparation survives turn changes. Only the recipient's next damaging card
  reserves it, including automatically played cards. The first damaging hit
  consumes the reservation once; support cards, the other partner's attacks,
  periodic damage, and counterattacks cannot spend it. The recipient owns the
  visible preparation and detail summary, independently of the source's survival.

Cold Snap deals Freeze damage before checking Frozen for its draw; newly applied
Frozen qualifies. Blood Offering pays 2 Health, deals 1 Bleed, then draws a card.
