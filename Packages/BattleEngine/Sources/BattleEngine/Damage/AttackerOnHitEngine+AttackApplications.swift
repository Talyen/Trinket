import Foundation
import TrinketContent
import TrinketCore

/// Attack-only afflictions and rewards, in their original on-hit order.
extension AttackerOnHitEngine {
    static func applyTalentAttackApplications(
        to state: inout DamageResolutionState,
        hit: Hit,
        in context: inout BattleState,
    ) {
        applyRangedAndPhysicalAfflictions(to: &state, hit: hit, in: &context)
        applyHolyAfflictions(to: &state, hit: hit, in: &context)
        applyBasicAttackApplications(to: &state, hit: hit, in: &context)
        applyTargetStateReactions(to: &state, hit: hit, in: &context)
        applyRandomOnHitApplications(to: &state, hit: hit, in: &context)
    }

    private static func applyRangedAndPhysicalAfflictions(
        to state: inout DamageResolutionState,
        hit: Hit,
        in context: inout BattleState,
    ) {
        let triggers = hit.triggers
        let target = state.combatant
        if triggers.attacksApplyPoison > 0, state.options.isBasicAttackHit,
           context.roster.health(for: target) > 0 {
            state.damageEvents.append(contentsOf: context.applyDecayingDoT(
                keyword: .poison,
                potency: triggers.attacksApplyPoison,
                to: target,
                sourceActorID: hit.sourceActorID,
                application: .reaction,
            ))
        }
        if triggers.physicalAttackApplyBleed > 0, hit.keyword == .physical,
           context.roster.health(for: target) > 0 {
            appendTargetBleed(potency: triggers.physicalAttackApplyBleed, state: &state, context: &context)
        }
        if triggers.physicalAttackApplyBleedAndStun > 0, hit.keyword == .physical,
           context.roster.health(for: target) > 0 {
            appendTargetBleed(potency: triggers.physicalAttackApplyBleedAndStun, state: &state, context: &context)
            state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
                triggers.physicalAttackApplyBleedAndStun,
                keyword: .stun,
                to: target,
                sourceActorID: hit.sourceActorID,
                applyFightPacing: false,
                in: &context,
            ))
        }
        if triggers.onPhysicalDamageGainBlock > 0, hit.keyword == .physical {
            appendAttackerBlock(triggers.onPhysicalDamageGainBlock, abilityName: "Bone Shield", state: &state, context: &context)
        }
    }

    private static func applyHolyAfflictions(
        to state: inout DamageResolutionState,
        hit: Hit,
        in context: inout BattleState,
    ) {
        let triggers = hit.triggers
        let target = state.combatant
        guard hit.keyword == .holy, context.roster.health(for: target) > 0, triggers.holyAttackApplyBurnAndStunBuildup > 0 else { return }
        state.damageEvents.append(contentsOf: context.applyDecayingDoT(
            keyword: .burn,
            potency: triggers.holyAttackApplyBurnAndStunBuildup,
            to: target,
            sourceActorID: hit.sourceActorID,
            application: .reaction,
        ))
        state.damageEvents.append(contentsOf: ControlMeterEngine.applyMeterCharge(
            triggers.holyAttackApplyBurnAndStunBuildup,
            keyword: .stun,
            to: target,
            sourceActorID: hit.sourceActorID,
            applyFightPacing: false,
            in: &context,
        ))
    }

    private static func applyBasicAttackApplications(
        to state: inout DamageResolutionState,
        hit: Hit,
        in context: inout BattleState,
    ) {
        let triggers = hit.triggers
        guard state.options.isBasicAttackHit, context.roster.health(for: state.combatant) > 0 else { return }
        let target = state.combatant
        if state.damageKeyword != .holy {
            let holyBonus = CombatTriggerEngine.livingAllyModifiers(in: context)
                .reduce(0) { $0 + $1.triggers.partyBasicAttackHolyBonus }
            state.damageEvents.append(contentsOf: DamagePipeline.resolveNestedDamage(
                amount: holyBonus,
                keyword: .holy,
                target: target,
                sourceActorID: hit.sourceActorID,
                requireTargetAlive: true,
                requireSourceAlive: hit.source,
                in: &context,
            ).events)
        }
        if triggers.basicAttackApplyBleed > 0 {
            appendTargetBleed(potency: triggers.basicAttackApplyBleed, state: &state, context: &context)
        }
        if triggers.basicAttackFreezeBuildup > 0 {
            state.damageEvents.append(contentsOf: DamagePipeline.resolveNestedDamage(
                amount: triggers.basicAttackFreezeBuildup,
                keyword: .freeze,
                target: target,
                sourceActorID: hit.sourceActorID,
                in: &context,
            ).events)
        }
        if triggers.basicAttackStealGold > 0 {
            state.damageEvents.append(contentsOf: context.grantGoldEvent(
                triggers.basicAttackStealGold,
                to: hit.source,
                abilityName: "Snatch",
                isTheft: true,
                isDirectCardGain: state.options.isCardAttack,
            ))
        }
    }

    private static func applyTargetStateReactions(
        to state: inout DamageResolutionState,
        hit: Hit,
        in context: inout BattleState,
    ) {
        let triggers = hit.triggers
        let target = state.combatant
        let targetAlive = context.roster.health(for: target) > 0
        let targetIsFrozen = context.roster.hasControlStatus(for: target, keyword: .freeze)
        let targetIsStunned = context.roster.hasControlStatus(for: target, keyword: .stun)
        let targetIsPoisoned = context.roster.hasAffliction(.poison, on: target)
        let targetIsBleeding = context.roster.hasAffliction(.bleed, on: target)
        if triggers.onAttackStealGold > 0 {
            state.damageEvents.append(contentsOf: context.grantGoldEvent(
                triggers.onAttackStealGold + (targetIsPoisoned ? triggers.stealGoldBonusVsPoisoned : 0),
                to: hit.source,
                abilityName: "Pickpocket",
                isTheft: true,
                isDirectCardGain: state.options.isCardAttack,
            ))
        }
        if triggers.onAttackBleedingEnemyHeal > 0, targetIsBleeding, targetAlive {
            state.damageEvents.append(contentsOf: applyBleedingPreyHeal(
                triggers: triggers,
                source: hit.source,
                in: &context,
            ))
        }
        if triggers.onAttackFrozenEnemyGainMana > 0, targetIsFrozen {
            state.damageEvents.append(contentsOf: context.restoreManaEmitting(
                triggers.onAttackFrozenEnemyGainMana,
                to: hit.source,
                abilityName: "Frost Siphon",
            ))
        }
        if triggers.onAttackFrozenEnemyGainBlock > 0, targetIsFrozen {
            appendAttackerBlock(triggers.onAttackFrozenEnemyGainBlock, abilityName: "Frost Guard", state: &state, context: &context)
        }
        if triggers.onAttackStunnedEnemyGold > 0, targetIsStunned {
            state.damageEvents.append(contentsOf: context.grantGoldEvent(
                triggers.onAttackStunnedEnemyGold,
                to: hit.source,
                abilityName: "Disorienting Strike",
            ))
        }
        if triggers.onAttackStunnedEnemyBlock > 0, targetIsStunned {
            appendAttackerBlock(triggers.onAttackStunnedEnemyBlock, abilityName: "Disorienting Strike", state: &state, context: &context)
        }
        if hit.source.role == .hero, targetIsPoisoned, targetAlive {
            state.damageEvents.append(contentsOf: CombatTriggerEngine.companionSpitPoison(
                to: target,
                in: &context,
            ))
        }
    }

    private static func applyRandomOnHitApplications(
        to state: inout DamageResolutionState,
        hit: Hit,
        in context: inout BattleState,
    ) {
        let triggers = hit.triggers
        let target = state.combatant
        if triggers.directHitBleedChancePercent > 0, context.roster.health(for: target) > 0,
           BattleChance.succeeds(probability: triggers.directHitBleedChancePercent, using: &context.rng) {
            appendTargetBleed(potency: 1, state: &state, context: &context)
        }
        if triggers.dazingSwipeChancePercent > 0, triggers.dazingSwipeStunDamage > 0,
           state.options.isAttackHit, state.damageKeyword == .physical,
           !state.options.isRetaliation, context.roster.health(for: target) > 0,
           context.claimTalentAbility("Dazing Swipe", actorID: hit.sourceActorID),
           BattleChance.succeeds(probability: triggers.dazingSwipeChancePercent, using: &context.rng) {
            state.damageEvents.append(contentsOf: DamagePipeline.resolveNestedDamage(
                amount: triggers.dazingSwipeStunDamage,
                keyword: .stun,
                target: target,
                sourceActorID: hit.sourceActorID,
                in: &context,
            ).events)
        }
        if triggers.attackApplyBleed > 0, state.options.isAttackHit,
           context.roster.health(for: target) > 0 {
            appendTargetBleed(potency: triggers.attackApplyBleed, state: &state, context: &context)
        }
        if triggers.attackBurstChancePercent > 0, context.roster.health(for: target) > 0,
           BattleChance.succeeds(probability: triggers.attackBurstChancePercent, using: &context.rng) {
            let burstDamage = max(0, triggers.attackBurstDamage)
            if burstDamage > 0 {
                state.damageEvents.append(contentsOf: DamagePipeline.resolveNestedDamage(
                    amount: burstDamage,
                    keyword: .physical,
                    target: target,
                    sourceActorID: hit.sourceActorID,
                    in: &context,
                ).events)
            }
            let burstBlock = max(0, triggers.attackBurstBlock)
            if burstBlock > 0 {
                appendAttackerBlock(burstBlock, abilityName: "Bone Burst", state: &state, context: &context)
            }
        }
    }
}
