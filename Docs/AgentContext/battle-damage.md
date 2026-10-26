# Damage and effect contracts

Use with [engine ownership](battle-engine.md) for damage, reactions, effect application or expiry.

## Operations and Block resolution

`DamageOperation` supplies named attack, effect, periodic, reaction, and Health-cost
operations. Damage type owns Stun/Freeze buildup; callers do not opt into it with
a flag. Counterattacks and repeated hits carry explicit origins; repeating periodic
or reaction damage preserves its operation kind. Copied and redirected damage have
distinct kinds with outgoing scaling already resolved. Status-tick construction
distinguishes natural ticks from secondary pulses. Card-repeat capture and replay
have explicit roles; repeating a packet clears capture, natural-tick eligibility,
and the partner's first-attack bonus while retaining accuracy, critical settings,
Leech, Thorns, and elemental settlement timing. Elemental attacks defer settlement
until attachment through a named transformation. Shared packet predicates own
primary-attack and damage-reward eligibility; live reaction checkpoints remain in
the ordered pipeline. `DamageDefensePolicy`
owns mitigation and Block bypass multipliers, while the shield steps in
`DamagePipeline` resolve borrowed Block before recipient Block through one
owner-based absorption step, preserving each checkpoint's order and rounding.
Consume stacked shields as one Block pool in stored order; break reactions fire only
after all positive shields are exhausted. Commit each pool before its reactions and read the next pool from live state. Ally protection uses the actual
Block owner's absorption bonuses and records that owner for The Patient Edge and
The Knight's Answer; borrowed Block does not claim the recipient's allowance.
Incoming Block-breaking rules also apply to borrowed Block, including Corrosive
Venom stripping its owner's Block before absorption. Its fixed strip amount is
shared by the borrowed and recipient Block pools within one damage packet.
Halving, decay, and costs replace an existing Block pool without granting a new
buff; prevention of Block gains cannot erase its remainder.
Block-breaking multipliers scale the Block points consumed after the owner's
absorption efficiency, capped at the remaining pool; absorbed damage stays unchanged.
Block theft, Pulverize, Bone-Crushing Bite, and Sunder Shield report actual removed
Block as loss feedback, without creating absorption or Block-break reactions.
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
subtracting it and clamping damage. Burn and Poison detonations preserve source-owned
decay and tick rules, plus applicable living-party enemy-pool decay Talents.
Resolution depth limits recursion, never changes the meaning of a request.
DoT amplification multiplies every matching stack, retaining each stack's source
and duration; its feedback reports the combined amplified potency only when at
least one stack grows. Fully capped pools emit no amplification feedback. Legacy
`multiplyDoT` respects negative-status protection on the existing debuff; growth
does not consume Fae Ward's interception of a new debuff.

## Enemy identity traits

Blood Offering pays 1 Health once before each attack action and attaches 1 Bleed
to its hits. The cost bypasses Block and mitigation, follows ordinary Health-cost
affordability, and is paid again for a repeated attack; support actions and
intercepted actions do not pay. Pilfer steals up to 1 Block from the selected
opponent before an attack, using ordinary theft feedback and prevention.
Firestarter attaches 1 Burn once per Basic action, including Basics whose damage
is authored as an effect; Skill, Ultimate and later status ticks do not apply it.

Plague Mask restores 1 Health after an opponent actually loses Health to Poison,
including ongoing Poison from any source. It does not reward blocked damage,
Poison damage to the wearer, or a defeated wearer. Reform restores 1 Health at
the beginning of each enemy turn, before control skips. Both use ordinary healing
modifiers, caps and feedback. Hollow Frame prevents all Leech restoration from
its wearer, including companion-to-Hero Leech, before chance rolls and rewards;
it does not prevent the attack damage.

## Saturation and conditional damage

Card preparations, DoT attachment/growth/detonation, and triggered Thorns gains
and retaliation saturate at integer limits, including when an existing effect
has already reached its maximum magnitude. Equipment and talent damage additions,
Backdraft snapshots, combined Block-breaking bonuses, and Golden Crucible storage
also saturate. Fully capped Thorns and Kindled grants preserve their existing stack
and report no application or success feedback. Card, talent and Block-driven
Thorns grants share the same admitted replacement; rejected grants preserve existing
stacks. Effect-detail totals and percentage formatting use the same bounded arithmetic, so inspecting capped preparations cannot crash.
Loose Rubble readies a non-stacking one-point reduction on positive Health damage,
including periodic and retaliation damage, excluding Health costs. The next positive
outgoing packet consumes it after outgoing calculations and before flat mitigation
and Block; dodges and non-damaging actions preserve it. A redirected packet does
not consume a second reduction. Seismic Pulse can consume it. Its prevented amount
logs as damage reduction and does not contribute damage chips or hit sounds.
Watchful Guard grants Block in the opening round as well as later rounds.
Blood Scent, Bulwark Force, Dread Exploitation, and Fan the Flames amplify enemy
attacks, not ongoing damage. Stormbreak's damage multiplier also applies to Bleed
ticks against Stunned enemies; resolved Burn and Poison keep their stored potency.
Infected adds flat damage to existing Bleed against Poisoned enemies, including
ticks and damage from fallen sources; it creates no Poison hit or stack.
Toxic Incense adds flat damage only to Holy attacks against Poisoned enemies,
including counterattacks. Raw Holy retaliation and ongoing damage do not qualify.
Ashen Wake adds flat damage to existing Burn against Poisoned enemies; Cauterize
adds flat damage to existing Bleed against Burning enemies. Both check the target
at each damage event, including resolved ticks and damage from fallen sources,
and create neither secondary hits nor new afflictions.
Prismatic Edge's copied initial damage skips these conditional source bonuses;
its later ordinary Burn ticks retain their per-event bonuses.
Later damage components skip a target already defeated by the same action, so
post-defeat hits cannot trigger another on-hit reward; later support effects still resolve.

## Stored damage and detonation

`DecayingDoTProgression` captures the original stack owner’s legacy decay and tick
rules plus the strongest matching enemy-pool Talent modifiers from living allies.
Enemy-pool Talents apply regardless of the original applier; defeated owners cease
contributing. Turn handlers and `DecayingDoTDetonation` use that same policy and
`Effect.potencyAfterTurn`; adding potency retains original source and tick credit.
Slowed decay still removes at least one positive potency per step, so detonations
cannot stall against damage prevention. Preservation and growth rolls remain exclusive to live turns. Ability and critical-hit
detonations share the executor; callers commit stack removal and own recursion scope
before executing damage.

Burn and Poison attached by damaging attacks or effect applications store the
actual Health damage dealt by that damage instance, after offensive bonuses,
critical damage, mitigation and Block. Fully blocked, dodged or otherwise
zero-Health-damage applications attach no stacks. This rule is identical for
party members and enemies. Blazing Feathers leaves
stacks equal to its own hit's Health loss, without another immediate hit.
Subsequent Burn/Poison ticks, consumed-stack damage
and detonations use resolved potency: do not repeat outgoing flat/percent bonuses,
critical multipliers or fight pacing. Current recipient defenses still apply.
Reaction damage reports its own Health loss separately from nested control,
Block, or healing events; those events retain their original meaning. Hemorrhage
emits its own trigger event only for actual Health loss, preserving Block and
Death's Door reactions in feedback and history. Hidden Fangs
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
counting universal bonuses once, including companion status multipliers, Critical
damage bonuses, and chance-based damage multipliers such as Supernova and Standard
Deviation. [Loaded Strike and legacy Standard Deviation](battle-talents.md#reproving-light-perfect-purity-and-loaded-strike)
retain their distinct eligibility, action rolls, and rounding. Shared numeric bonuses include
damage to Block: Shatterguard applies to Oathkeeper Holy damage, while Flaming Arrows
and Armor Shred apply to the other
Bloodember keyword. Block absorption and attack-only eligibility remain unchanged. Thermal
Shock and Cold Flame apply once per new hit.
Searing Body attaches Burn after attack Health damage, never after periodic or
reaction damage. Unquenchable Flame bypasses talent damage reduction as well as
flat mitigation, typed resistance and Block; unapplied prepared protection remains ready.

## Repeats, retaliation and living-owner rewards

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
Retaliatory reflection receives Spitebloom's conditional damage and can earn
Spiteful after positive Health damage, sharing Spiteful's once-per-turn allowance
with a consumed Thorns stack.
Its Physical reflection also observes Thorns resistance.
Periodic Burn grants its damage rewards through the damage pipeline, including
detonation and direct tick commands. Natural-turn Holy pings and Bleed detonation
riders remain exclusive to natural ticks.
Committed Thorns, lingering Bleed, and lingering Burn still deal damage after
their source falls. Burn retains living allies' Ember Shield reactions, while its
fallen source cannot earn healing, Block, or Mana rewards.
Other personal rewards require a living owner: Martial Guard's Block, both
Blood Money rewards, Golden Verdict's Stun theft, and Critical Hit Gold stop after
final defeat.
Holy-triggered Purge and target weakening also stop if retaliation defeats their
source; the Holy damage already committed remains.
Red Harvest detonates Bleed and Huntsmaster’s Call draws a Companion card only
after Physical Critical Hits remove Health.
Cutpurse Knife rolls a fixed 10% chance per positive Bleed damage packet to steal
Gold equal to damage remaining plus damage absorbed by Block, including fully
Blocked hits and periodic Bleed. Theft modifiers apply afterward; a defeated
wearer receives nothing. Older flat-payout powers normalize to this rule.
Fully Blocked Critical Hits still qualify for ordinary Critical Hit Gold and Purge
reactions; effects that explicitly require Health damage keep that requirement.
Spitebloom adds flat damage to existing Thorns against Poisoned enemies before
recipient defenses, including Retaliatory reflection; it creates no Poison hit or stack.
Venomtrail checks Bleed at each Poison damage event, including resolved ticks;
it adds flat damage without replaying general outgoing bonuses. Hallowbreak
increases Holy damage against Stunned targets, stacking with talent bonuses.
Brittle, Dazed, and Heavy Flail's damage bonuses against Frozen or Stunned targets
belong to the attacker with the affix or talent; they do not amplify partner damage.
Hallowguard snapshots the attacker's Block before a Holy attack and grants Block
only if that attack removes enemy Health.

Cinderbound adds flat Burn damage against Bleeding enemies at each damage event,
including resolved ticks, without creating a secondary hit or new stack.
Steadfast and Arcane reward their wearer's completed Stun only when that wearer
has no Block or Mana respectively; Mana restoration still requires capacity.
Shattering deals Physical reaction damage after its wearer completes a Freeze.
Resolute heals its wearer at the existing Block-break checkpoint; Reactive deals
Stun reaction damage to the surviving attacker. Both can repeat on subsequent
Block breaks in the same turn and keep Saintfall's separate allowance intact.
Kinbound heals a living wearer below half Health from their living ally's actual
attack Health damage, using ordinary combat rounding and healing. Periodic,
retaliation and repeated damage do not qualify; either party member may wear it.
Bloodletting rolls once per card after its first qualifying Physical Health hit,
including automatic card plays. Blocked hits do not spend its roll. Multi-hit cards
share the roll, a later card can roll again in the same turn, and repeated or
reaction damage cannot roll. Copies add chance (capped at 100%); a successful
roll deals one Bleed damage through the ordinary reaction/DoT applicator.

## Mutation checkpoints, removal and expiry

Keep ordered
damage checkpoints in `DamagePipeline`; commit mutations before their dependent
reactions. Reserve next-hit resources before nested reactions and never write a
cached effects array back after a reaction. `EffectRemovalOperation` owns removal and
all cleanse consequences together. Its purge path likewise commits removals
before protection and rewards; dependent damage reads its actual removed effects.
Affix rewards for Purge require at least one buff removed from an enemy; an empty
Purge never grants Block or deals Holy damage.
Knockout and Disrupting require their wearer to cause the Stun; Branding observes
Stun from any source. Recheck the wearer between Stun reactions and after Purge
before Wardbreaker's follow-up damage. Companion attack rewards likewise stop
after theft, healing, or Purge reactions defeat their owner.
Removal events report what was actually removed: one event per removed buff for
purge, one per distinct keyword for cleanse. Empty purge reports `didApply:false`;
empty cleanse still reports any heal and side-effect events as applied
(`didApply` reflects emitted events).
Random Purge selects from the surviving eligible buffs in original stack order,
preserving the seeded RNG stream. Multi-keyword Cleanse retains keyword order and
original stack order within each keyword for reflection.
Legacy debuff reflection returns a triggered Stun or Freeze at the recipient's control
threshold, so a larger enemy Health pool cannot turn the reflected status into
partial buildup. Untriggered buildup retains its removed amount.
`DoTApplication.reflection` preserves the
removed potency and duration without new-application bonuses or immediate damage.
Turn handlers commit their own effect updates and emit into command output. Decaying
DoTs commit decay before ticking; duration-based effects age the live effect after
their tick, and Death's Door is removed before expiry reactions. `EffectTurnEngine`
only schedules existing effect IDs and never writes a returned snapshot back.
Burn details show the current amount and describe damage and halving each turn.
Poison details show the current amount and describe damage and a 25% decrease each turn.
Bleed details show the current amount and describe damage each turn until expiry.
Burn and Poison amounts do not guarantee next-turn damage; Stun and Freeze buildup details show
percentage progress and explain that reaching 100% prevents the next action.

For a named talent change, look up its rule in [talent interactions](battle-talents.md).

## Control and lethal protection

Glacial Barrier and Rimeguard reward each living owner when an opponent becomes
Frozen, including freezes applied by an ally.
Cool Moss adds the living Druid's bonus to allied Freeze damage against Poisoned
enemies. Nerve Agent and Entangling Growth increase allied Stun build-up against
Poisoned enemies while their Hero lives; the Hero's own bonus applies once.
Control extensions belong to the active Freeze or Stun that earned them. Simultaneous
statuses retain their own skipped actions; Cleanse removes the corresponding extension
without removing another status's extension or an independent action delay.
Freeze amplification and flat Block bonuses saturate before applying their caps.
Control extension rolls convert whole guaranteed skips in constant time and saturate
the stored allowance; non-finite chances grant no extension. Stun from a fallen
source may still control its target, but cannot grant that source Block.

`DamageDefensePolicy` applies damage caps
to ordinary damage operations, exempting Health costs.
After lethal protection restores a party member, living-owner Health-loss rewards
include Grizzly Guard and Redline. A final defeat grants neither; Second Wind
keeps its pre-protection checkpoint.

## Universal reactions

The Hero and Companion share earned reaction progress on the enemy. Store it in
`CombatantRuntime` with its copy-on-write state; packet snapshots belong to damage
outcomes, and natural-phase facts belong to `CombatResolution`. Fresh battles reset
progress. Interrupted battles still restart; no save schema or mid-battle resume is
introduced.

Only ordinary attacks and full automatic card plays can release attack reactions.
Toxic Shock instead releases on a fresh successful Stun, including non-damaging
control; partial buildup and hits against an already Stunned target do not release it.
Counterattacks, repeats, equipment or talent damage, retaliation, periodic damage,
and detonations cannot release attack reactions. Their successful control can still
prepare control bonuses and release Toxic Shock.
Freeze separately prepares Shatter and Frostfire; Stun prepares Rupture. Each
stores one quarter of its own packet's actual Health loss, rounded once, minimum
one. Non-damaging control prepares one. Extensions and turn resets cannot refresh
these opportunities; removal or recovery expires them.

- Shatter: a positive, undodged Physical attack against a Frozen enemy strips all
  enemy Block before mitigation, then releases its stored Physical bonus. Ordinary
  Critical rules remain on the attack; the bonus cannot Critical.
- Frostfire: a Freeze attack successfully Freezing a Burning enemy, or a Burn hit
  removing Health from a previously Frozen enemy, releases one stored Burn bonus.
  These routes share one Freeze opportunity, independent of Shatter.
- Rupture: a Bleed attack removing Health from an enemy already Stunned before the
  hit releases the stored Bleed bonus, once per Stun. The bonus adds no Bleed stack.
- Toxic Shock: positive natural Poison damage from two enemy phases prepares a
  quarter of their combined Health loss. Successfully becoming Stunned releases all
  completed pairs as Poison damage, without adding Poison. Unmatched ticks and
  prepared damage survive Poison ending and being reapplied.
- Consecration: Holy Health damage against an already Bleeding enemy marks its next
  natural Bleed phase, releasing one quarter of that phase's Bleed Health loss as
  Holy damage. Marks do not stack. Capture and consume the mark at the first natural
  Bleed tick; clearing or detonating Bleed before then cancels it.
- Bloodboil: positive natural Burn and Bleed Health loss in one phase release one
  quarter of their combined loss as Burn damage, after Consecration.
- Venomflash: an eligible Burn hit removes Health and ignites an already Poisoned
  enemy with no prior Burn, releasing one quarter of pre-hit Poison potency as Burn
  damage. Ignition is recorded before follow-up detonation can consume the fire.

Natural phases retain existing status order and decay. Only the first normal tick
of each scheduled effect contributes; extra ticks, application pulses, recurring
damage and detonations do not. Multiple Bleeds contribute one combined phase total.
Control-skipped enemy turns count. Expired statuses can still contribute the Health
loss they already dealt. Quarter calculations divide before summing to avoid
integer overflow and round the combined amount once.

Reaction damage is already resolved: bypass defenses and outgoing scaling, retain
survival/Health-threshold handling and once-only kill credit, and do not add status
stacks, attack riders or recursive reaction damage. Attack payoffs wait for ordinary
follow-ups and retaliation, and require their triggering ally and enemy to survive.
Consecration retains its Holy source; Bloodboil uses the last contributing natural
Bleed source. Fallen sources retain periodic damage but cannot earn personal living
owner rewards. `ActionEvent.Kind.reaction` announces names separately from numerical
damage events; rules never infer identity from localized names or event searches.

Existing content keeps its saved identifiers and effects: the Shatter affix is
Brittle, Mana Moth's Frostfire is Cold Flame, Knight's Consecration is Hallowed Guard,
and Ranger's Wildfire tree is Firecraft.

## Quiet item affixes

Relay, Prismatic, Measured, Breakthrough, Catalytic, Discerning, and Unburdened
modify existing attack damage without an additional event or damage packet.
They exclude ongoing damage and raw retaliation. Prismatic compares each wearer's
primary enabled attack type with their own previous attack; support cards do not
reset it. One action retains that comparison across all hits and prepared card
repeats. The first attack has no previous type and earns no bonus.
Relay readies the living partner's next landed attack hit after an attack card
finishes; another card refreshes its magnitude instead of accumulating it.
Measured compares current Block before absorption. Catalytic requires both Burn
and Poison. Discerning counts distinct removable buff kinds, not their stacks.
Unburdened requires no removable debuffs on the attacker. Breakthrough increases
only positive Health overflow from the hit that exhausts the enemy's own Block;
it cannot amplify a fully blocked hit, bypassed Block, or later unblocked hits.
Resolved attack repeats check their own fresh Block absorption, without repeating
outgoing damage bonuses.
