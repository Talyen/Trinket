---
type: execution-plan
status: active
created: 2026-09-14
updated: 2026-09-14
expires: 2026-09-28
---

# Keyword cohesion and concise mechanics

## Objective and current disposition

Give every talent, ability, enemy trait, and item affix at least one meaningful,
recognized keyword in its player-facing description. Players should understand
the effect quickly and see how it expresses its name and fantasy theme.

This document records the full proposed implementation, including the latest
Unique-item revisions and the Returning Gale turn-transition requirement.
Saving this plan does not implement or verify the proposed gameplay changes.

The initial audit checked 65 abilities, 446 talents, 39 enemy traits, and 94
standard affixes using the game's actual keyword matcher. It found 19 entries
without a keyword: 2 abilities, 11 talents, 1 enemy trait, and 5 standard affixes.
Both Basic and Astral descriptions were affected for those five affixes. A later
check of the separate bespoke Unique catalog found five additional missing
signatures; they are included below. Additional ability changes address theme
and readability even where a keyword already exists.

### Locked product decisions

- Use the existing 17 keywords. Do not introduce Mark, Critical Hit, Draw, or
  other new glossary keywords for this work.
- Aim for approximately ten words per proposed description. Preserve normal
  grammar, articles, subjects, targets, and established phrasing such as
  "Deal 3 Physical damage." A slightly longer complete sentence is preferable
  to fragments or omitted context.
- Simplify mechanics when the full rule cannot be described concisely. Do not
  hide required conditions or durations in a secondary tooltip to meet the
  word target.
- Keyword references must describe a real mechanic, not merely satisfy a text
  check. Prefer accurate copy changes when sufficient; preserve each item's
  theme when changing its effect.
- Leave Pixie Dust and Astral Arrow entirely unchanged, including their names,
  damage types, magnitudes, randomness, and descriptions.
- Rename only Sap Arrow to Bandit's Arrow. Preserve its saved ability ID.
- Use the exact requested Tithe, Bounty Shot, and Avatar descriptions below,
  including the requested capitalization of Steal.
- Preserve other content outside the listed changes. In particular, do not
  revise every existing description to meet a new global word limit.
- Keep the specified magnitudes fixed during implementation. Run balance
  comparisons and report concerns rather than silently retuning these values.

## Ability changes

"Before" is the description audited in the current catalogs, not an earlier
proposal from this conversation. Bold text in the final column identifies
existing keywords; authored strings should use the ordinary text renderer.

| Ability | Before | Final description |
| --- | --- | --- |
| Sniff Out | Mark the enemy. | Your party's next attack deals 3 additional **Physical** damage. |
| Predator's Focus | Mark the enemy. Your next attack is a guaranteed Critical Hit. | Your next attack is guaranteed to Critically Hit and **Leech**. |
| Sap Arrow → Bandit's Arrow | Deal 3 Stun damage. If the enemy is Stunned, gain 2 Gold. | Deal 3 **Stun** damage and steal 2 **Gold**. |
| Golden Plate | Gain 3 Block, Gold, and Thorns. Your Hero and Companion each dodge the next attack. | Gain 8 **Block** and 5 **Gold**. |
| Maul | Deal 2 Stun damage or deal 2 Bleed damage. | Deal 2 **Stun** or **Bleed** damage at random. |
| Cinderbloom | Deal 3 Burn damage or deal 3 Poison damage. | Deal 3 **Burn** or **Poison** damage at random. |
| Tithe | Deal 3 Holy damage or steal 3 Gold. | Deal 2 **Holy** damage and Steal 2 **Gold**. |
| Bounty Shot | Deal 3 Physical damage or steal 3 Gold. If the enemy is Marked, gain both. | Deal 3 **Physical** damage and Steal 2 **Gold**. |
| Ray of Frost | Deal 1 Freeze damage now and each turn for 2 turns. | Deal 1 **Freeze** damage now and for 2 more turns. |
| Blizzard | Deal 4 Freeze damage now and each turn for 2 turns. | Deal 4 **Freeze** damage now and for 2 more turns. |
| Earthquake | Deal 4 Stun damage now and each turn for 2 turns. | Deal 4 **Stun** damage now and for 2 more turns. |
| Avatar | Deal 7 Holy damage and gain 2 Block now and each turn for 2 turns. | Deal 6 **Holy** damage now and for 2 more turns. |
| Sunburst | Deal 6 Holy damage and Restore 6 Health. | Deal 6 **Holy** damage. Restore 3 **Health** to each ally. |
| Pounce | Deal 3 Stun damage. Doubled if played on the first turn. | Deal 3 **Stun** damage, doubled on the first combat turn. |

### Ability mechanics

- **Sniff Out:** replace Mark with a shared party preparation. The next ordinary
  party attack gains 3 Physical damage on one original enemy-directed hit.
  Preserve the original attack's damage types; this is a typed Physical bonus,
  not a conversion of the whole attack. Reuse the existing typed preparation
  approach so repeated hits and equipment bonuses do not multiply the grant.
- **Predator's Focus:** remove Mark and prepare the caster's next attack to
  Critically Hit and Leech using the ordinary critical and Leech pipelines.
  An attack already granting Leech must not receive a duplicate base Leech.
- Both preparations persist until consumed or combat ends. Reapplication
  refreshes that source's preparation rather than accumulating copies. A
  preparation cannot be consumed by the card that created it.
- **Bandit's Arrow:** deal 3 Stun damage and steal 2 Gold unconditionally;
  remove the Stunned-target condition.
- **Tithe:** replace random branches with one action dealing 2 Holy damage and
  stealing 2 Gold.
- **Bounty Shot:** replace random branches and the Mark condition with one
  action dealing 3 Physical damage and stealing 2 Gold. Gold is fixed, not
  proportional to damage or Health lost.
- **Golden Plate:** grant the caster 8 Block and 5 Gold. Remove Thorns and both
  party Dodge effects.
- **Avatar:** preserve an immediate pulse and two subsequent turn pulses, each
  dealing 6 Holy damage. Remove its Block grant. Base damage totals 18 before
  ordinary combat modifiers.
- **Sunburst:** deal 6 Holy damage and restore 3 Health to each living party
  member. Replace the single lowest-Health recipient; do not revive defeated
  members.
- **Maul, Cinderbloom, Ray of Frost, Blizzard, Earthquake, and Pounce:** change
  wording only. Preserve current random outcomes, timing, and conditions.
- Mark's existing behavior remains unchanged for remaining sources such as
  Branding. Do not implement the abandoned Dodge-bypass proposal: enemy
  rules prohibit Dodge, so that proposal would not provide its intended value.

## Talent changes

| Talent and owner | Before | Final description |
| --- | --- | --- |
| Spell Echo — Wizard | Skills you empower play twice. | Skills empowered with **Mana** play twice. |
| Thick Hide — Bear | Take 2 less damage from all hits. | Take 2 less **Physical** damage from each hit. |
| Ironhide — Bear | Bear cannot take more than 12 damage in a single hit. | Lose at most 12 **Health** per hit. |
| Dazing Swipe — Bear | Attacks have a 25% chance to delay the enemy's turn. | Attacks have a 25% chance to deal 3 **Stun** damage. |
| Surprise Strike — Panther | Gain +15% Critical Hit chance. | Your first **Physical** attack each combat always Critically Hits. |
| Shadow Camouflage — Panther | If Panther isn't attacked during the enemy turn, its next attack deals 1 additional damage. | Playing a non-damaging card makes you **Dodge** the next attack. |
| Guardian — Golden Retriever | Absorb 2 damage whenever the Hero is attacked. | Grant the Hero 2 **Block** before they are attacked. |
| Warning Bark — Golden Retriever | Negate the first enemy attack of each combat. | Your party **Dodges** the first enemy attack each combat. |
| Man's Best Friend — Golden Retriever | Hero gains +15% Critical Hit chance while Retriever is alive. | The Hero's Critical Hits restore 1 **Health** to each ally. |
| Dense Bones — Risen Skeleton | Take 1 less damage from each hit (up to 4). | Your **Block** absorbs twice as much **Physical** damage. |
| Purifying Aura — Pixie | Negative effects on all party members expire twice as fast. | **Cleanse** 1 negative effect from each ally every other turn. |

### Talent mechanics

- **Spell Echo and Ironhide:** wording only. Preserve existing behavior and
  Ironhide's separation from voluntary Health costs.
- **Thick Hide:** retain flat reduction of 2, restricted to Physical damage.
- **Dazing Swipe:** replace the independent action-delay chance with a 25%
  chance per qualifying attack to deal 3 Stun damage through normal control
  buildup. The reaction must not recursively trigger itself.
- **Surprise Strike:** remove the unconditional critical-chance bonus. Guarantee
  the wearer's first qualifying Physical attack each combat Critically Hits;
  preceding non-Physical attacks do not consume this opportunity.
- **Shadow Camouflage:** after Panther plays a non-damaging ordinary card,
  grant its normal next-attack Dodge preparation. Sniff Out and Predator's
  Focus qualify. Refresh rather than stack Dodge charges, and activate ordinary
  Dodge reactions when the preparation is consumed.
- Use the shared resolved-action classification for Shadow Camouflage. An
  attack prevented by Block remains damaging; zero actual Health loss does not
  make it a support card. Preparing future damage is not current attack damage.
  Automatic abilities and reactions must not recursively grant new allowances.
- **Guardian:** replace flat Hero mitigation with a grant of 2 Block before an
  incoming attack targeting the Hero resolves. Grant once per incoming attack,
  not for each component of a multi-hit attack or for ongoing damage.
- **Warning Bark:** preserve protection against one enemy attack per combat,
  including that attack's multiple hits, but route the protection through Dodge
  feedback and ordinary Dodge reactions for the protected target. Claim its
  combat allowance before resolving reactions.
- **Man's Best Friend:** replace the Hero critical-chance aura with 1 Health
  restoration to each living ally on a damaging Hero Critical Hit. Healing
  Critical Hits cannot recursively activate this effect.
- **Dense Bones:** replace accumulating flat reduction with doubled Block
  absorption capacity against Physical damage. Other damage types retain normal
  Block efficiency. Verify partial absorption and odd amounts using the
  existing combat rounding policy; do not halve unrelated Health damage.
- **Purifying Aura:** replace accelerated duration expiry with one ordinary
  random Cleanse per living ally every other player turn. Use existing cadence
  helpers, beginning on player turn 1, and normal Cleanse reactions. This
  intentionally reaches Burn and Poison, unlike the old timed-expiry effect.
- Preserve living-owner requirements for Companion talents and existing
  saved talent IDs and purchases.

## Enemy trait and standard affixes

Trinket descriptions apply to both Basic and Astral versions.

| Entry | Before | Final description |
| --- | --- | --- |
| Mimic trait | Deals double damage on the first attack. | Its first attack deals 2 additional **Bleed** damage. |
| Beastbond — Basic | Your Companion deals 1 additional damage. | Increase your Companion's **Physical** damage by 1. |
| Beastbond — Astral | Your Companion deals 2 additional damage. | Increase your Companion's **Physical** damage by 2. |
| Retaliatory — Basic | Reflect 10% of damage taken. | Reflect 10% of **Health** lost as **Physical** damage. |
| Retaliatory — Astral | Reflect 20% of damage taken. | Reflect 20% of **Health** lost as **Physical** damage. |
| Shredding — Basic | Ignore 10% of enemy mitigation. | Your **Physical** damage ignores 10% of enemy damage reduction. |
| Shredding — Astral | Ignore 25% of enemy mitigation. | Your **Physical** damage ignores 25% of enemy damage reduction. |
| Loyal Companion | Draw an extra Companion card every other turn. | Once per turn, **healing** your Companion draws a Companion card. |
| Forbidden Knowledge | Draw an additional card every other turn. | Every other turn, lose 1 **Health** and draw 2 cards. |

- **Mimic:** replace its first-attack doubling with one additional 2 Bleed
  damage hit on its first attack. Use ordinary Bleed damage and application;
  do not grant the bonus again on subsequent hits or ongoing ticks.
- **Beastbond:** restrict its existing Companion damage bonus to Physical
  damage; do not add a separate Physical attack to every non-Physical attack.
  Update its signature affinity from Health to Physical.
- **Retaliatory:** wording only. Its current retaliation is Physical damage
  based on actual Health lost, despite the internal trigger's Thorns name.
- **Shredding:** restrict its mitigation penetration to Physical damage while
  preserving its current separation from Block penetration.
- **Loyal Companion:** replace automatic alternate-turn draws with a draw from
  the Companion's deck when the wearer actually restores the Companion's
  Health, at most once per player turn. Overhealing alone does not qualify.
  Claim the allowance before attempting the draw, even if a card is unavailable.
- **Forbidden Knowledge:** on its existing alternate-turn cadence, beginning
  on player turn 1, pay 1 Health and draw 2 cards from the wearer's deck. Use
  ordinary Health-cost and living-actor continuation rules. Do not add a hidden
  nonlethal floor. Resolve the cost before drawing.

## Unique-item signatures: latest thematic revision

The initial five-Physical proposal is superseded by this table. Physical remains
appropriate for a keen blade and recovering arrows; hunting wounded prey,
patient defense, and evasive movement use Bleed, Block, and Dodge respectively.
Names, base items, and existing supporting powers remain unchanged. Update each
signature's keyword metadata and feedback to match its new mechanic.

| Unique | Current signature | Final proposed description | Theme |
| --- | --- | --- | --- |
| Everkeen | Once per turn, your first Critical Hit strikes again. | Your first **Physical** Critical Hit each turn strikes again. | Precision from an exceptionally sharp blade. |
| Huntsmaster's Call | Your first Critical Hit each turn makes your Companion use its Basic Ability. | Your **Bleed** damage triggers your Companion's Basic Ability once per turn. | Wounded prey signals the hunting companion to follow up. |
| The Patient Edge | Your first attack each turn deals +2 damage if your partner has already played a card. | **Blocking** an attack makes your next attack Critically Hit. | Defend and wait for the decisive opening. |
| The Returning Gale | The third card you play each turn returns to your hand after resolving. | **Dodging** returns the last card you played to your hand. | Evasive movement brings another opportunity around. |
| The Returning Flight | At turn start, recover your last attack card from the previous turn, if it remains in your deck. | Your first **Physical** card each turn returns to your hand. | A quiver that retrieves its spent arrows. |

### Unique mechanics and limits

- **Everkeen:** retain one repeat per wearer per player turn, but require a
  Physical Critical Hit. Earlier non-Physical Critical Hits do not spend the
  allowance. Preserve the existing resolved-damage repeat behavior; do not
  reroll or apply the critical multiplier a second time.
- **Huntsmaster's Call:** trigger on the wearer's positive Bleed damage,
  including its ongoing damage, once per player-turn cycle. Claim the allowance
  before the Companion uses its equipped Basic Ability. Preserve normal
  targeting, resource, control, and living-actor restrictions. Companion attacks
  and reaction chains cannot recursively summon themselves.
- **The Patient Edge:** after Block actually absorbs attack damage, prepare
  the wearer's next ordinary attack to Critically Hit. Gaining Block alone and
  blocking ongoing damage do not qualify. The preparation refreshes rather than
  stacks and persists until consumed or combat ends. Remove the old partner-card
  condition, first-attack damage bonus, and once-per-turn damage opportunity.
- **The Returning Gale:** track the wearer's last ordinary card play, including
  non-damaging cards. On that wearer's Dodge, move that exact played ability
  from its deck back to hand using normal card-return rules. Do nothing if it
  is already held or buffered, absent from the deck, or unavailable under normal
  owner restrictions. Repeated Dodges cannot create additional copies. Automatic
  abilities do not replace the tracked ordinary card.
- **The Returning Flight:** return the wearer's first played Physical card each
  player turn after its effects and on-play draws finish. Count Physical cards
  using shared card identity rules. Claim the allowance before returning the
  card, so replaying it cannot repeatedly return it. Move the actual card;
  do not also cycle it into the deck.
- Existing Unique ownership, singleton, equipped support-power, and corruption
  rules continue to apply. The two card-return signatures must also work when
  equipped together without duplicating the same ability.

### Returning Gale across the enemy turn

Source inspection confirmed that the engine preserves the current hand when the
next player turn starts. It then attempts to draw one Hero card and one Companion
card. It does not discard the existing hand and deal a replacement hand.

The visible hand is capped at three cards. Additional cards enter the existing
FIFO overflow buffer and become visible when space opens. Therefore a card
returned by an enemy-turn Dodge can survive into the next player turn, either
visible or buffered. Ordinary owner defeat/control removal rules still apply;
the turn change itself must not discard the returned card.

Implementation must preserve the tracked last ordinary play through the enemy
turn and complete card recovery before its relevant state is reset. Retain the
returned card through normal turn-start draws and preserve FIFO ordering.

This lifecycle was checked in the existing turn and hand code. The new
Dodge-triggered signature has not been implemented or runtime-tested yet.

## Implementation ownership and compatibility

Follow the current routed ownership instructions when implementation starts;
the workspace contains unrelated in-flight work and must be checked again.

- Author ability changes in the existing Basic, Skill, and Ultimate catalogs.
  Prefer generated descriptions when they can express the agreed text; update
  formatter support and description-override validation together where needed.
- Author ordinary talent, trait, and affix changes in the content manifests.
  Author bespoke signatures in the Unique catalogs. Never hand-edit generated
  catalogs or the ability inventory.
- Extend existing effect/trigger contracts only where required. Effect identity
  and presentation belong to the existing core/content owners; combat execution,
  per-turn allowances, last-card tracking, and preparations remain in BattleEngine.
  Use the architect skill when introducing public effect, modifier, or schema
  contracts, and the apple-design skill for player-facing text and UI review.
- Reuse normal damage, critical, Leech, Block, Dodge, Cleanse, Health-cost, and
  card-return pipelines. Preserve selected random outcomes, automatic-play
  ancestry, source attribution, and existing reaction recursion safeguards.
- Preserve all saved IDs, purchases, inventory ownership, artwork, and unrelated
  modifiers. Display-name changes must not alter ability/loadout identifiers.
- Normalize affected stored affix powers through the existing item-resolution
  path before item-base scaling. Handle both currently stored forms and older
  legacy forms. Update stored/resolved descriptions alongside mechanics so an
  existing item cannot advertise its retired effect.
- Preserve rolled values where the base magnitude is unchanged. When a base
  changes, carry the existing roll/corruption adjustment relative to its old
  base into the new base. Render the resulting actual magnitude with correct
  singular/plural wording; do not overwrite it with a catalog-default sentence.
- Pay particular attention to Loyal Companion's older per-turn/per-other-turn
  draw fields and Patient Edge's older held-card and partner-damage fields.
  Their resolved powers must adopt the final effects above. New trigger fields
  decode to inactive defaults; migration must be deterministic and idempotent.
  Preserve legacy decoding while stored consumers remain supported.
- Keep unique supporting powers and unrelated ordinary affixes intact. Update
  only signature affinities whose mechanics changed; avoid treating an internal
  fallback Physical tag as proof that the effect deals Physical damage.
- Update canonical behavior and unique-item documentation with implemented
  rules. Generate catalogs through the repository pipeline and verify a second
  generation is unchanged.

Relevant canonical guidance:

- [Content and manifests](../AgentContext/content-and-manifests.md)
- [Action, card, and Mana contracts](../AgentContext/battle-actions.md)
- [Damage and effects](../AgentContext/battle-damage.md)
- [Talent interactions](../AgentContext/battle-talents.md)
- [Unique equipment](../Product/UniqueItems.md)
- [Balance](../AgentContext/battle-balance.md)
- [Testing](../Platform/Testing.md)
- [Verification](../Platform/Verification.md)

## Verification and acceptance criteria

### Content and description coverage

- Check the actual rendered summaries/descriptions with the shared keyword
  matcher across all abilities, talents, enemy traits, ordinary Basic/Astral
  affixes, bespoke Unique powers, and affected resolved saved-item descriptions.
- Do not count a keyword present only in an item's affinity metadata or title.
  Include supported keyword inflections such as Blocking, Dodging, and healing.
- Review all changed descriptions for concise, complete grammar and truthful
  mechanics. Use approximately ten words as an editorial target, not a reason
  to invent abbreviations or conceal required rules.
- Confirm Pixie Dust and Astral Arrow are unchanged and the final Tithe, Bounty
  Shot, and Avatar text/magnitudes exactly match the explicit user choices.

### Consequential combat cases

- Sniff Out and Predator's Focus: preparation refresh and consumption, shared
  versus wearer ownership, multi-hit/repeated attacks, typed bonuses, and
  pre-existing Leech without duplicate healing.
- Deterministic paired effects: Bandit's Arrow, Tithe, and Bounty Shot produce
  their fixed damage and Gold outcomes without retired branch conditions.
- Avatar and other recurring abilities: immediate pulse plus exactly two
  subsequent pulses. Avatar no longer grants Block. Sunburst heals each living
  ally and does not revive a defeated one.
- Shadow Camouflage: support cards qualify; damaging cards with fully Blocked
  damage do not; repeated support cards refresh one Dodge; normal Panther Dodge
  reactions run without recursive preparation or duplicate charges.
- Guardian and Warning Bark: correct target, pre-attack timing, once-per-attack
  versus once-per-combat behavior, multi-hit attacks, and ordinary Dodge reactions.
- Dense Bones: Physical versus non-Physical hits, zero/partial/sufficient Block,
  odd damage values, and interactions with damage reduction and Block penetration.
- Man's Best Friend and Purifying Aura: living owners/recipients, actual Cleanse
  reactions, and no recursive critical-healing loop.
- Loyal Companion: positive restoration versus overhealing, one claim per turn,
  deck availability, buffered draws, and no healing/draw loop.
- Forbidden Knowledge: Health cost before draw, low Health, Death's Door,
  defeated-owner continuation, alternate-turn cadence, and unavailable draws.
- Everkeen and Huntsmaster's Call: qualifying typed damage, correct cadence,
  early ineligible events not spending allowances, and non-recursive follow-ups.
- Patient Edge: actual attack damage absorbed by Block, preparation refresh,
  and consumption without retired partner/damage behavior.
- Mimic: one opening Bleed bonus through the normal damage pipeline, not a
  bonus repeated on every attack component or ongoing tick.

### Returning Gale regression required by the user

1. Play an ordinary card and end the player turn.
2. Force the wearer to Dodge during the enemy turn.
3. Assert the same previously played ability returns from its owner's deck,
   without another copy remaining in that deck.
4. Complete the enemy turn, state resets, and normal next-turn draws.
5. Assert the returned ability remains available in the visible hand or buffer.
6. Repeat with a full three-card visible hand and existing buffered cards;
   assert FIFO order, no overflow loss, and later promotion when a slot opens.
7. Repeat the Dodge before replaying the card; assert there is no duplicate.
8. Cover no prior play, already-held/absent cards, ordinary owner restrictions,
   and simultaneous ownership of The Returning Flight.

### Save, balance, and presentation checks

- Cover legacy/current affix payloads, both ordinary rarity tiers, Unique
  signatures, rolled/corrupted magnitudes, base scaling, repeated normalization,
  and save/reload consistency of displayed text and effective mechanics.
- Run focused paired ability, talent, and affix balance comparisons for semantic
  changes, plus Mimic encounter checks. Inspect stalls and interactions rather
  than treating an absence of sparse-sample flags as proof of balance. Report
  concerns without silently changing the agreed design or numbers.
- Inspect changed cards and detail views using the managed Simulator workflow.
  Confirm keyword emphasis, readable wrapping, actual long item/ability names,
  and no truncation. Do not create broad snapshot coverage for a copy-only edit.
- Run required path-scoped handoff for the union of implemented and adopted
  changes, including this plan. Review generated consistency and the final diff.

## Execution checklist

- [x] Record catalog findings, user constraints, final explicit overrides, and
  the latest thematic Unique proposals.
- [x] Confirm existing hand preservation and overflow behavior from source.
- [ ] Recheck scoped status, current consumers, and routed ownership guidance.
- [ ] Implement agreed content, effect, and trigger changes without altering
  Pixie Dust, Astral Arrow, or unrelated in-flight work.
- [ ] Implement saved-power normalization and matching description updates.
- [ ] Add or adapt the consequential regression cases above.
- [ ] Update canonical docs, regenerate outputs, and verify idempotence.
- [ ] Review focused balance evidence and player-facing descriptions.
- [ ] Complete scoped handoff and report remaining evidence gaps precisely.
- [ ] Once implementation is complete, record its outcome in
  [the archive index](Archived/README.md) and delete this active plan.

Until implementation is complete, retain this file as an intentionally active
plan. The documentation-only save request does not close the gameplay work.
