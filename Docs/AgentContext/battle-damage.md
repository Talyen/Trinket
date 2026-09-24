# Damage and effect contracts

Use with [engine ownership](battle-engine.md) for damage, reactions, effect application or expiry.

`DamageOperation` supplies named attack, effect, periodic, reaction, and Health-cost
operations. Damage type owns Stun/Freeze buildup; callers do not opt into it with
a flag. Counterattacks and repeated hits carry explicit origins; repeating periodic
or reaction damage preserves its operation kind. Redirected damage enters the
recipient's defenses with outgoing scaling already resolved. `DamageDefensePolicy`
owns mitigation and Block bypass multipliers, while the shield steps in
`DamagePipeline` own Intercede absorption on top of those multipliers,
preserving each checkpoint's order and rounding. Multiple partial Block bypasses
use the strongest applicable fraction. Partial bypass scales each defense before
subtracting it and clamping damage. Burn detonation preserves the original
source's decay rate and ticks per turn. Blackfletch's Poison detonation likewise
preserves the original source's slower decay. Resolution depth limits recursion, never changes
the meaning of a request.
Later damage components skip a target already defeated by the same action, so
post-defeat hits cannot trigger another on-hit reward; later support effects still resolve.
Turn ticks and detonations share `Effect.potencyAfterTurn` for deterministic decay;
random growth remains a turn-processing rule.

Burn and Poison attached by damaging attacks or effect applications store the
actual Health damage dealt by that damage instance, after offensive bonuses,
critical damage, mitigation and Block. Fully blocked, dodged or otherwise
zero-Health-damage applications attach no stacks. This rule is identical for
party members and enemies. Subsequent Burn/Poison ticks, consumed-stack damage
and detonations use resolved potency: do not repeat outgoing flat/percent bonuses,
critical multipliers or fight pacing. Current recipient defenses still apply.
Explicit non-damaging stack grants and reflection retain their specified potency;
neither gains outgoing bonuses. Ticks never attach new stacks. Bleed and authored
recurring damage retain their separate rules. Combustion still adds its Burn before
detonating all remaining Burn, including the fresh application.
Barbed adds flat damage to a consumed Thorns stack before blocked or poisoned
Thorns multipliers; it does nothing without an active Thorns stack.
Bristling checks Block remaining after the incoming hit. Spiteful heals only
when Thorns removes enemy Health, at most once per wearer per turn.
Spitebloom follows Thorns Health damage with a separate Poison hit and attaches
Poison only from Health actually lost to that hit.
Venomtrail checks Bleed at each Poison damage event, including resolved ticks;
it adds flat damage without replaying general outgoing bonuses. Hallowbreak
increases Holy damage against Stunned targets, stacking with talent bonuses.
Hallowguard snapshots the attacker's Block before a Holy attack and grants Block
only if that attack removes enemy Health.

Keep ordered
damage checkpoints in `DamagePipeline`; commit mutations before their dependent
reactions. Reserve next-hit resources before nested reactions and never write a
cached effects array back after a reaction. `CleanseOperation` owns removal and
all cleanse consequences together. `PurgeOperation` likewise commits removals
before protection and rewards; dependent damage reads its actual removed effects.
Affix rewards for Purge require at least one buff removed from an enemy; an empty
Purge never grants Block or deals Holy damage.
Removal events report what was actually removed: one event per removed buff for
purge, one per distinct keyword for cleanse. Empty purge reports `didApply:false`;
empty cleanse still reports any heal and side-effect events as applied
(`didApply` reflects emitted events).
`DoTApplication.reflection` preserves the
removed potency and duration without new-application bonuses or immediate damage.
Turn handlers commit their own effect updates and return only events. Decaying
DoTs commit decay before ticking; duration-based effects age the live effect after
their tick, and Death's Door is removed before expiry reactions. `EffectTurnEngine`
only schedules existing effect IDs and never writes a returned snapshot back.

For a named talent change, look up its rule in [talent interactions](battle-talents.md).

`DamageDefensePolicy` applies damage caps
to ordinary damage operations, exempting Health costs.
