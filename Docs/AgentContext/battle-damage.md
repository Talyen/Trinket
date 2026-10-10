# Damage and effect contracts

Use with [engine ownership](battle-engine.md) for damage, reactions, effect application or expiry.

`DamageOperation` supplies named attack, effect, periodic, reaction, and Health-cost
operations. Damage type owns Stun/Freeze buildup; callers do not opt into it with
a flag. Counterattacks and repeated hits carry explicit origins; repeating periodic
or reaction damage preserves its operation kind. Redirected damage enters the
recipient's defenses with outgoing scaling already resolved. `DamageDefensePolicy`
owns mitigation and Block bypass multipliers, while the shield steps in
`DamagePipeline` resolve borrowed Block before recipient Block through one
owner-based absorption step, preserving each checkpoint's order and rounding.
Commit each pool before its reactions and read the next pool from live state. Ally protection uses the actual
Block owner's absorption bonuses and records that owner for The Patient Edge and
The Knight's Answer; borrowed Block does not claim the recipient's allowance.
Incoming Block-breaking rules also apply to borrowed Block, including Corrosive
Venom stripping its owner's Block before absorption. Its fixed strip amount is
shared by the borrowed and recipient Block pools within one damage packet.
Block-breaking multipliers scale the Block points consumed after the owner's
absorption efficiency, capped at the remaining pool; absorbed damage stays unchanged.
Glacial Reprieve deals three Freeze damage on its owner's first Block absorption
each turn, including borrowed Block. Ironhide reduces overflow only from an attack that breaks
the recipient's Block; ongoing damage and bypass damage leaving Block intact do not qualify.
Shieldbreaker, Shield Breaker, and Brittle Strike apply their Physical Block-breaking
multiplier only to attacks. Physical retaliation retains ordinary Block consumption;
generic Sundering and Holy damage bonuses keep their separate eligibility.
Heavy Impact and Heavy Slam amplify the owner's Physical retaliation against
Stunned enemies. Stalk the Wound also amplifies its owner's Bleed ticks against
Bleeding enemies below half Health.
Multiple partial Block bypasses
use the strongest applicable fraction. Partial bypass scales each defense before
subtracting it and clamping damage. Burn detonation preserves the original
source's decay rate and ticks per turn. Blackfletch's Poison detonation likewise
preserves the original source's slower decay. Resolution depth limits recursion, never changes
the meaning of a request.
Loose Rubble readies a non-stacking one-point reduction on positive Health damage,
including periodic and retaliation damage, excluding Health costs. The next positive
outgoing packet consumes it after outgoing calculations and before flat mitigation
and Block; dodges and non-damaging actions preserve it. A redirected packet does
not consume a second reduction. Seismic Pulse can consume it.
Watchful Guard grants Block in the opening round as well as later rounds.
Blood Scent, Bulwark Force, Dread Exploitation, and Fan the Flames amplify enemy
attacks, not ongoing damage. Stormbreak's damage multiplier also applies to Bleed
ticks against Stunned enemies; resolved Burn and Poison keep their stored potency.
Infected, Cauterize, and Ashen Wake react to positive Health damage, including
ticks, rather than stack attachment. Infected can successfully trigger only once
per wearer per turn; failed rolls do not spend its allowance. Silent stack grants
do not trigger them.
Later damage components skip a target already defeated by the same action, so
post-defeat hits cannot trigger another on-hit reward; later support effects still resolve.
`DecayingDoTProgression` captures the original stack owner’s decay and tick rules
for Burn and Poison. Turn handlers and `DecayingDoTDetonation` use that same
policy and `Effect.potencyAfterTurn`; preservation and growth rolls remain exclusive
to live turns. Ability and critical-hit detonations share the executor; callers
commit stack removal and own recursion scope before executing damage.

Burn and Poison attached by damaging attacks or effect applications store the
actual Health damage dealt by that damage instance, after offensive bonuses,
critical damage, mitigation and Block. Fully blocked, dodged or otherwise
zero-Health-damage applications attach no stacks. This rule is identical for
party members and enemies. Blazing Feathers, Toxic Incense, and Toxic Remedy leave
stacks equal to their own hit's Health loss, without another immediate hit.
Subsequent Burn/Poison ticks, consumed-stack damage
and detonations use resolved potency: do not repeat outgoing flat/percent bonuses,
critical multipliers or fight pacing. Current recipient defenses still apply.
Reaction damage reports its own Health loss separately from nested control,
Block, or healing events; those events retain their original meaning. Hidden Fangs
likewise reports its immediate Bleed loss before attaching its opening stack.
Explicit non-damaging stack grants and reflection retain their specified potency;
neither gains outgoing bonuses. Ticks never attach new stacks. Bleed and authored
recurring damage retain their separate rules. Combustion still adds its Burn before
detonating all remaining Burn, including the fresh application.
Enemy pulse traits retain their flat immediate damage and attach the corresponding
DoT afterward: authored potency for Bleed, actual Health damage for Burn and Poison.
Resolved outgoing packets also skip source talent multipliers already included in
their magnitude. Newly readied Toxic Backlash still doubles the next Poison damage
event once, including a stored tick; Venomtrail retains its per-event rule below.
Oathkeeper and Bloodember share keyword percentage bonuses as well as flat bonuses,
counting universal bonuses once. Thermal Shock and Frostfire apply once per new hit.

The Final Spark snapshots each original packet's outgoing magnitude and Critical
Hit result before recipient defenses. Its repeat uses current defenses without
rerolling or consuming another source preparation. Threefold Grace checks every
positive qualifying Health-damage packet, including periodic and reaction damage,
without enabling other keyword reactions on those paths.
Barbed adds flat damage to a consumed Thorns stack before blocked or poisoned
Thorns multipliers; it does nothing without an active Thorns stack.
Bristling checks Block remaining after the incoming hit. Spiteful heals only
when Thorns removes enemy Health, at most once per surviving wearer per turn.
Thorns retaliation keeps its Physical or converted damage type and also observes
Thorns resistance, including Briar Ward; ordinary Physical damage does not.
Retaliatory reflection can trigger Spitebloom and earn Spiteful after positive
Health damage, sharing Spiteful's once-per-turn allowance with a consumed Thorns stack.
Its Physical reflection also observes Thorns resistance.
Committed Thorns and lingering Bleed still deal damage after their source falls.
Their personal rewards require a living owner: Martial Guard's Block, both
Blood Money rewards, and Critical Hit Gold stop after final defeat.
Spitebloom follows Thorns Health damage with a separate Poison hit and attaches
Poison only from Health actually lost to that hit.
Venomtrail checks Bleed at each Poison damage event, including resolved ticks;
it adds flat damage without replaying general outgoing bonuses. Hallowbreak
increases Holy damage against Stunned targets, stacking with talent bonuses.
Shatter, Dazed, and Heavy Flail's damage bonuses against Frozen or Stunned targets
belong to the attacker with the affix or talent; they do not amplify partner damage.
Hallowguard snapshots the attacker's Block before a Holy attack and grants Block
only if that attack removes enemy Health.

Keep ordered
damage checkpoints in `DamagePipeline`; commit mutations before their dependent
reactions. Reserve next-hit resources before nested reactions and never write a
cached effects array back after a reaction. `EffectRemovalOperation` owns removal and
all cleanse consequences together. Its purge path likewise commits removals
before protection and rewards; dependent damage reads its actual removed effects.
Affix rewards for Purge require at least one buff removed from an enemy; an empty
Purge never grants Block or deals Holy damage.
Removal events report what was actually removed: one event per removed buff for
purge, one per distinct keyword for cleanse. Empty purge reports `didApply:false`;
empty cleanse still reports any heal and side-effect events as applied
(`didApply` reflects emitted events).
Reflective Ward returns a triggered Stun or Freeze at the recipient's control
threshold, so a larger enemy Health pool cannot turn the reflected status into
partial buildup. Untriggered buildup retains its removed amount.
`DoTApplication.reflection` preserves the
removed potency and duration without new-application bonuses or immediate damage.
Turn handlers commit their own effect updates and return only events. Decaying
DoTs commit decay before ticking; duration-based effects age the live effect after
their tick, and Death's Door is removed before expiry reactions. `EffectTurnEngine`
only schedules existing effect IDs and never writes a returned snapshot back.
Burn and Poison details show current potency and explain decay before turn damage;
current potency is not a guaranteed next-turn damage amount.

For a named talent change, look up its rule in [talent interactions](battle-talents.md).

Glacial Barrier and Rimeguard reward each living owner when an opponent becomes
Frozen, including freezes applied by an ally.
Cool Moss adds the living Druid's bonus to allied Freeze damage against Poisoned
enemies. Nerve Agent and Entangling Growth increase allied Stun build-up against
Poisoned enemies while their Hero lives; the Hero's own bonus applies once.
Control extensions belong to the active Freeze or Stun that earned them. Simultaneous
statuses retain their own skipped actions; Cleanse removes the corresponding extension
without removing another status's extension or an independent action delay.

`DamageDefensePolicy` applies damage caps
to ordinary damage operations, exempting Health costs.
After lethal protection restores a party member, living-owner Health-loss rewards
include Grizzly Guard and Redline. A final defeat grants neither; Second Wind
keeps its pre-protection checkpoint.
