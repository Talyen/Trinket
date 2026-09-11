# Damage and effect contracts

Use with [engine ownership](battle-engine.md) for damage, reactions, effect application or expiry.

`DamageOperation` supplies named attack, effect, periodic, reaction, and Health-cost
operations. Damage type owns Stun/Freeze buildup; callers do not opt into it with
a flag. Counterattacks and repeated hits carry explicit origins; repeating periodic
or reaction damage preserves its operation kind. Redirected damage enters the
recipient's defenses with outgoing scaling already resolved. `DamageDefensePolicy`
owns mitigation and Block bypass, including Intercede, while preserving each
checkpoint's order and rounding. Partial bypass scales each defense before
subtracting it and clamping damage. Burn detonation preserves the original
source's decay rate and ticks per turn. Resolution depth limits recursion, never changes
the meaning of a request.

Keep ordered
damage checkpoints in `DamagePipeline`; commit mutations before their dependent
reactions. Reserve next-hit resources before nested reactions and never write a
cached effects array back after a reaction. `CleanseOperation` owns removal and
all cleanse consequences together. `DoTApplication.reflection` preserves the
removed potency and duration without new-application bonuses or immediate damage.
Turn handlers commit their own effect updates and return only events. Decaying
DoTs commit decay before ticking; duration-based effects age the live effect after
their tick, and Death's Door is removed before expiry reactions. `EffectTurnEngine`
only schedules existing effect IDs and never writes a returned snapshot back.

For a named talent change, look up its rule in [talent interactions](battle-talents.md).

`DamageDefensePolicy` applies damage caps
to ordinary damage operations, exempting Health costs.
