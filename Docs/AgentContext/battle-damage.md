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

Keep ordered
damage checkpoints in `DamagePipeline`; commit mutations before their dependent
reactions. Reserve next-hit resources before nested reactions and never write a
cached effects array back after a reaction. `CleanseOperation` owns removal and
all cleanse consequences together. `PurgeOperation` likewise commits removals
before protection and rewards; dependent damage reads its actual removed effects.
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
