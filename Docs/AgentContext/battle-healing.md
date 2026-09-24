# Healing and gain contracts

Use with [engine ownership](battle-engine.md) for healing, overflow, bounded gains or party auras.

`HealingResult` carries `HealingAllocation`: resolved healing, direct restoration,
transferred overflow, maximum-Health and Block allocations, and unspent overflow.
Each consuming consequence allocates from the remainder. Transfers offer at most
the recipient's missing Health so nested healing cannot convert overflow already
owned by the parent. Echoes and Leech success read actual restoration. Independent
observers such as Wishspring read original overflow without consuming it.
Healing emits original overflow as an `overheal` event, including at full Health.
Floating feedback combines it with restored Health in the existing healing number;
restoration events, battle-log totals, and healing triggers still use actual restoration.
`CombatGain` owns bounded applied gains; proportional effects use `CombatRounding`
without an implicit minimum-one grant. Lingering Blessing stores its amount,
source, and remaining duration together.
Block grants declare a base or resolved amount through `BlockAmountBasis`.
Duplication, transfer, and already-scaled gains use `.resolved` to avoid applying
outgoing bonuses and fight pacing again; consequences read `BlockGain.applied`.
Bloodward rolls only when Leech directly restores Health, then grants a resolved
Block amount equal to that restoration. Overflow does not fund its Block.
Bloodroot grants Thorns after direct Leech restoration only when the wearer has
no Thorns. Scarfeast grants Leech to the wearer's Physical attacks while their
Health was below half before the hit.
Heartshock reacts only to direct Leech restoration below half Health. Its Stun
follow-up cannot Leech, so it cannot trigger another Heartshock hit.
Restorative rolls its Cleanse chance only after Health is actually restored.
Clearheaded and Solace reward each status effect removed, not an empty Cleanse.
Rekindled restores Health only when its wearer survives Death's Door expiry.
Boolean party-aura checks use `hasLivingPartyTrigger` rather than merging every
trigger group on nested reaction paths.

Damage operations and caps use [damage contracts](battle-damage.md). For a named talent change, look up [talent interactions](battle-talents.md).

`HealingOrigin` owns healing rules and Critical Hit
eligibility independently of logging. Single-recipient Health restoration from
current abilities, talents, and equipment selects the living ally with the
lowest current Health on the source's side. Leech and its shares, party-wide
heals, revivals and self-preservation at a Health threshold, attached repeats,
and explicit overflow or partner transfers keep their intended recipients.

Verdant Renewal retains its saved `healthPerTurn` trigger field and restores
2 Health on alternate player turns beginning on turn 1.

Blessed Aegis grants the caster 5 Block, restores 5 Health to the lowest-Health
living ally, then deals 5 Holy damage. Each operation uses the ordinary gain or
damage pipeline. Luck Potion's Health outcome uses the same lowest-Health target.
