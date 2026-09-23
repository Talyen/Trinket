---
type: execution-plan
status: active
created: 2026-09-23
updated: 2026-09-23
expires: 2026-10-07
---

# Talent redesign

## Objective

Revise all 446 Talent nodes across 21 combatants and 63 keyword trees, then make
their actual mechanics match the approved text. Review each combatant in a table
showing the current effect beside the proposed effect. Keep each tree's current
node count. The user confirms there are no players or saves to migrate, so IDs
may change when a tree move requires it.

## Agreed design constraints

- Every Talent description must mention its tree's keyword or an inflection of
  it. Match the owner's one-Basic, one-Skill, one-Ultimate loadout pool; a Talent
  may reward a compatible owner loadout but must work with any partner.
- Follow Alchemy's concise, direct rules voice without periods. Trinket calls
  cards **abilities**; prefer damage, attack, or keyword wording when clearer.
  Do not use “buff” or “debuff”; use “positive status effect” or “negative status
  effect.” Avoid combatant names in descriptions.
- Give each Talent one clear trigger and payoff. Simplify the mechanic when its
  full rule cannot be explained clearly in roughly 12 words. Connect the trigger
  and payoff to the Talent name, combatant, and tree keyword.
- Avoid per-hit and per-tick side effects, crowded simultaneous floating combat
  feedback, and large multipliers under easily sustained conditions. A rare
  ability payoff may add one extra chip. Chance effects roll once per ability.
  Keep row power equivalent; scale payoffs to trigger difficulty. Avoid arbitrary
  caps.
- Battles start at full Health and Mana and currently have one enemy. Healing,
  Mana, Block, and draws awarded only after a kill or after combat have no useful
  combat window; persistent Gold rewards can remain. Keep at most one kill-only
  reward per tree.

## Review and implementation

- [x] Inventory authored Talents and compare Alchemy's wording and Trinket's
  Ability pool, keyword rules, battle mechanics, and feedback presentation.
  The current manifest has 29 descriptions that omit their own tree keyword;
  review those even if the user prefers their current design.
- [ ] Resolve the four Knight keyword-placement entries below; the other 17
  Knight effects and their wording are approved.
- [ ] Review the remaining combatants in current/proposed batches, recording the
  user's current, proposed, or modified choice for every node.
- [ ] Audit every selected effect for tree-keyword wording, viable owner loadout,
  thematic fit, simple mechanics, unique name and icon fit, and feedback density
  when all tree nodes are unlocked together. Strengthen catalog coverage to
  require each Talent's own tree keyword, rather than any keyword, in its text.
- [ ] Implement the approved catalog in `ContentManifest/talents.tsv`, the
  relevant trigger schemas and battle owners, then regenerate catalogs. Update
  canonical behavior guidance and meaningful deterministic coverage.
- [ ] Run routed, isolated handoff for all changed paths; review generated
  consistency and the final diff. Archive the plan outcome and delete this file
  when the whole redesign is complete.

## Knight · Stun — approved

| Talent | Approved description |
| --- | --- |
| Heavy Flail | Deal 3 additional damage to Stunned enemies |
| Concussive Blow | Stunned enemies deal half damage when they recover |
| Skullcracker | Stun Critical Hits deal double damage |
| Second Wind | When Stun ends, draw 1 ability |
| Searing Bind | Stun lasts 1 extra turn on Burning enemies |
| Crusader's Mark | Holy damage is increased by 5 against Stunned enemies |
| Lightning Rod | Stun damage is increased by half your Block |

## Knight · Block — six approved, one pending placement

| Talent | Description | Status |
| --- | --- | --- |
| Bastion Stance | Start combat with 6 Block | Approved |
| Spiked Barricade | Thorns damage is doubled while you have Block | Approved |
| Intercede | Your Block also absorbs damage dealt to your Companion | Approved |
| Guarded Impact (was Shield Bash) | Physical damage is increased by 25% of your Block | Approved |
| Shield Shatter | Physical attacks ignore half enemy Block | Approved mechanic; pending Holy-tree move |
| Unbreakable | Keep 75% of your Block between turns | Approved |
| Stalwart Oath | Below half Health, Block absorbs 50% more damage | Approved |

## Knight · Holy — four approved, three pending keyword fit

| Talent | Description | Status |
| --- | --- | --- |
| Oathbound | Holy damage is increased by 25% while you have Block | Approved |
| Pure Radiance | Holy damage is increased by 50% against enemy Block | Approved |
| Holy Infusion | Your Thorns deal Holy instead of Physical damage | Approved |
| Consecration | With Block, take half Burn, Poison, and Bleed damage | Approved mechanic; pending Block-tree move |
| Smite the Wicked | Purging an enemy doubles your next Holy attack | Approved |
| Divine Blessing | Once per combat, your Companion survives fatal damage at 8 Health | Approved intent; pending Holy-linked trigger |
| Sunwall | Your Companion takes 20% less damage while you have Block | Approved intent; pending Holy-linked rule |

### Proposed Knight keyword correction — awaiting selection

Keep seven nodes in each tree by moving Consecration into Block row 3 and Shield
Shatter into Holy row 2. Consecration keeps its approved effect. Shield Shatter
would become “Holy attacks ignore half enemy Block”; the change from Physical to
Holy needs the user's choice. Divine Blessing and Sunwall also need a real Holy
mechanic in their effect, not a decorative mention of the word.

## Other combatants

Earlier conversational drafts are unapproved. Record only the user's selected
current, proposed, or modified effect here as each combatant is reviewed. Audit
all of them for the tree-keyword rule before presenting a batch.
