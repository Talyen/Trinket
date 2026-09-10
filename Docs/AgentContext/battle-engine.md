# Battle engine context

Load for `Packages/BattleEngine` rules, effects, decks/hands, damage, triggers, or engine tests.

Start with `BattleState`, the matching `EffectHandlers/` type, or the matching `CombatTriggerEngine+*.swift` cadence extension. `BattleState` is a facade: put shared mutation plumbing in `BattleState+*.swift`; place rule branches in handlers or engines. Do not put feature calls in the engine. BattleState shares its immutable modifier profiles through private storage so nested card resolution does not copy those large values into every state snapshot.

On-hit and reaction work is split on purpose:

- `DamagePipeline` applies talent on-hit applications during damage resolution, including first-hit bonuses and attacker-ward DoTs.
- `CombatTriggerEngine` owns post-hit cadence such as after spend mana, after dodge, after cleanse, turn start/end, enemy turn, leech, and party auras.

Do not fold those cadences into the pipeline or merge affix scalar fields on `CombatModifierProfile` with `triggers`; the dual channel is intentional.

`DamageOperation` supplies named attack, effect, periodic, reaction, and Health-cost
operations. Damage type owns Stun/Freeze buildup; callers do not opt into it with
a flag. Counterattacks and repeated hits carry explicit origins; repeating periodic
or reaction damage preserves its operation kind. Redirected damage enters the
recipient's defenses with outgoing scaling already resolved. `DamageDefensePolicy`
owns mitigation and Block bypass, including Intercede, while preserving each
checkpoint's order and rounding. Partial bypass scales each defense before
subtracting it and clamping damage. Burn detonation preserves the original
source's decay rate and ticks per turn. Resolution depth limits recursion, never changes
the meaning of a request. `HealingOrigin` owns healing rules and Critical Hit
eligibility independently of logging.

`CombatResolution` owns nested action/card identity, selected outcomes, automatic-play
ancestry, and cadence claims. `ResolvedActionFacts` is an immutable shared record:
card reactions, talents, and Uniques read its selected outcome and qualifying
keywords, while talent execution results track what actually happened separately.
Capture facts at preparation; evaluate later operation conditions at their existing
execution checkpoints. Do not classify a played card from `possibleOperations` or
reconstruct its outcome from another talent's bookkeeping. Keep these immutable
records shared so nested actions do not copy their full payload onto the stack.
`BattleActionContext` likewise shares immutable participants while preserving value
equality; payment receipts and checkpoint eligibility retain actor IDs.

`CombatCheckpoint` checks eligibility before each ordered reaction. Prepared-action
and card-completion work requires a living actor; winning cards can finish support
rewards. Enemy action delays precede preparation, while attack-only interception
uses the selected outcome and rechecks control after reactions. Recovery rewards
require the final skipped action to finish. Committed damage consequences retain
their own source/target rules, including periodic damage from defeated sources.
Use `withAutomaticPlay` for automatic chains; counterattack ancestry follows its
action frame. Do not toggle a separate automatic-play flag. Keep ordered
damage checkpoints in `DamagePipeline`; commit mutations before their dependent
reactions. Reserve next-hit resources before nested reactions and never write a
cached effects array back after a reaction. `CleanseOperation` owns removal and
all cleanse consequences together. `DoTApplication.reflection` preserves the
removed potency and duration without new-application bonuses or immediate damage.
Turn handlers commit their own effect updates and return only events. Decaying
DoTs commit decay before ticking; duration-based effects age the live effect after
their tick, and Death's Door is removed before expiry reactions. `EffectTurnEngine`
only schedules existing effect IDs and never writes a returned snapshot back.

`Ability.operations` is the common traversal for classification, empowerment, and
execution; `possibleOperations` includes unresolved outcomes. `BattleActionContext`
binds the selected target for an action and resolves allies/opponents relative to
its actor. A defeated actor cannot continue; a winning card may still resolve its
remaining support rewards. New actions cannot start after battle ends.

`payMana` returns a `ManaPayment` with actual before/after balances. Capture every
contribution to an empowerment purchase before payment reactions; last-Mana rules
read receipts even after refunds or nested actions. Arcane Burst keeps excess
progress across cards and turns separately from cadence claims. Periodic rewards
use `playerTurnNumber` and `isPlayerTurn(every:startingAt:)`; stored `turnCount`
remains zero-based.

`HealingResult` carries `HealingAllocation`: resolved healing, direct restoration,
transferred overflow, maximum-Health and Block allocations, and unspent overflow.
Each consuming consequence allocates from the remainder. Transfers offer at most
the recipient's missing Health so nested healing cannot convert overflow already
owned by the parent. Echoes and Leech success read actual restoration. Independent
observers such as Wishspring read original overflow without consuming it.
`CombatGain` owns bounded applied gains; proportional effects use `CombatRounding`
without an implicit minimum-one grant. `DamageDefensePolicy` applies damage caps
to ordinary damage operations, exempting Health costs. Lingering Blessing stores its amount,
source, and remaining duration together. `BattleRoster.hasAffliction` distinguishes
active debuffs from keyword-associated buffs for conditions and damage rules.
Boolean party-aura checks use `hasLivingPartyTrigger` rather than merging every
trigger group on nested reaction paths.

For a new effect kind, maintain registry parity. Existing handler and turn-processing
coverage may suffice; add or extend `EffectHandlersApplyTests` only for a consequential
behavior gap. Use a thin integration case when a meaningful interaction cannot be
proved by the existing owner. Apply [Testing.md](../Platform/Testing.md) for value,
retirement, fixtures, seeds, and dispatch conventions.

Keep balance/scaling details in [battle-balance.md](battle-balance.md).
