# Healing and gain contracts

Use with [engine ownership](battle-engine.md) for healing, overflow, bounded gains or party auras.

`HealingResult` carries `HealingAllocation`: resolved healing, direct restoration,
transferred overflow, maximum-Health and Block allocations, and unspent overflow.
Each consuming consequence allocates from the remainder. Transfers offer at most
the recipient's missing Health so nested healing cannot convert overflow already
owned by the parent. Echoes and Leech success read actual restoration. Independent
observers such as Wishspring read original overflow without consuming it.
`CombatGain` owns bounded applied gains; proportional effects use `CombatRounding`
without an implicit minimum-one grant. Lingering Blessing stores its amount,
source, and remaining duration together.
Block grants declare a base or resolved amount through `BlockAmountBasis`.
Duplication, transfer, and already-scaled gains use `.resolved` to avoid applying
outgoing bonuses and fight pacing again; consequences read `BlockGain.applied`.
Boolean party-aura checks use `hasLivingPartyTrigger` rather than merging every
trigger group on nested reaction paths.

Damage operations and caps use [damage contracts](battle-damage.md). For a named talent change, look up [talent interactions](battle-talents.md).

`HealingOrigin` owns healing rules and Critical Hit
eligibility independently of logging.

Blessed Aegis grants independent Block and Holy retaliation to each living ally
of the caster. Enemy casters protect only their own side. Reapplying the Holy
ward refreshes it through the same rules as other on-hit wards.
