import Foundation
import TrinketContent
import TrinketCore

package extension DamagePipeline {
    static func applyDamageBonus(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        applyBaseAndScaledDamage(to: &state, in: &context)
        applyCompanionAttackBonuses(to: &state, in: &context)
        if state.options.isAttackHit, state.amount > 0 {
            let bonus = context.resolution.consumeGoldDamage(for: state.sourceActorID)
            state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, bonus)
            state.itemBonus = SaturatedArithmetic.saturatingAdd(state.itemBonus, bonus)
        }
        if state.amount > 0 {
            state.remaining = SaturatedArithmetic.saturatingAdd(
                state.remaining, context.resolution.consumePartyCardDamage(from: state.provenance),
            )
            applyPartyDamageBonus(to: &state, in: &context)
        }
        applyPercentBonus(to: &state, in: &context)
        applyDodgeEmpoweredBonuses(to: &state, in: &context)
        applyStunnedAndTalentMultipliers(to: &state, in: &context)
        applyBurnDamageMultipliers(to: &state, in: &context)
        applyOneShotEmpowers(to: &state)
        applyOutgoingReductions(to: &state, in: &context)
        applyStandardDeviation(to: &state, in: &context)
        state.dealt = state.remaining
    }

    private static func applyStandardDeviation(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.damageKeyword == .physical, state.remaining > 0,
              let sourceActorID = state.sourceActorID,
              context.modifiers(for: sourceActorID).triggers.standardDeviation else { return }
        let doubled: Bool
        if context.hasHeroCard(for: sourceActorID) {
            if let stored = context.resolution.cardTalents?.standardDeviationDouble {
                doubled = stored
            } else {
                doubled = Bool.random(using: &context.rng)
                context.mutateHeroCard { $0.standardDeviationDouble = doubled }
            }
        } else {
            doubled = Bool.random(using: &context.rng)
        }
        state.remaining = doubled ? SaturatedArithmetic.saturatingMul(state.remaining, 2)
            : state.remaining / 2 + state.remaining % 2
    }

    private static func applyBurnDamageMultipliers(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.damageKeyword == .burn, state.remaining > 0,
              let sourceActorID = state.sourceActorID else { return }
        let triggers = context.modifiers(for: sourceActorID).triggers
        if BattleChance.succeeds(probability: triggers.burnDamageDoubleChancePercent, using: &context.rng) {
            state.remaining = SaturatedArithmetic.saturatingMul(state.remaining, 2)
        }
        if state.options.isCardAttack,
           triggers.burnAttackDoubleChancePercent > 0,
           context.claimHeroCardBonus(.burnAttackDoubleChance, actorID: sourceActorID),
           BattleChance.succeeds(probability: triggers.burnAttackDoubleChancePercent, using: &context.rng) {
            state.remaining = SaturatedArithmetic.saturatingMul(state.remaining, 2)
        }
        if context.roster.hasControlStatus(for: state.combatant, keyword: .freeze),
           BattleChance.succeeds(probability: triggers.burnDoubleVsFrozenChancePercent, using: &context.rng) {
            state.remaining = SaturatedArithmetic.saturatingMul(state.remaining, 2)
        }
    }

    private static func applyBaseAndScaledDamage(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        if let sourceActorID = state.sourceActorID,
           let damageKeyword = state.damageKeyword,
           let actor = context.roster.combatant(for: sourceActorID) {
            state.statBonus = state.options.applyStatBonus
                ? CombatRounding.scaled(state.amount, multiplier: context.modifiers(for: sourceActorID).outgoingDamagePercent)
                : 0
            state.itemBonus = state.options.applyItemBonus
                ? outgoingDamageBonus(
                    for: sourceActorID,
                    keyword: damageKeyword,
                    in: context,
                )
                : 0
            if state.options.isAttackHit,
               var runtime = context.roster.runtime(for: actor.combatant) {
                let profile = context.modifiers(for: sourceActorID)
                if !runtime.hasTriggeredFirstHitBonus, profile.triggers.firstHitDoubleDamage {
                    state.itemBonus = SaturatedArithmetic.saturatingAdd(
                        state.itemBonus, SaturatedArithmetic.saturatingAdd(state.amount, state.statBonus),
                    )
                    runtime.hasTriggeredFirstHitBonus = true
                    context.roster.update(runtime)
                }
            }
            if state.options.applyItemBonus {
                state.itemBonus = SaturatedArithmetic.saturatingAdd(
                    state.itemBonus,
                    CombatTriggerEngine.damageBonus(for: state, in: &context),
                )
            }
        }
        state.remaining = SaturatedArithmetic.saturatingAdd(
            SaturatedArithmetic.saturatingAdd(state.amount, state.statBonus), state.itemBonus,
        )
        applyVenomtrail(to: &state, in: context)
    }

    private static func applyPercentBonus(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.options.applyItemBonus,
              let sourceActorID = state.sourceActorID,
              let damageKeyword = state.damageKeyword
        else { return }
        let profile = context.modifiers(for: sourceActorID)
        var percent = profile.damageDealtPercent(for: damageKeyword)
        if let sharedKeyword = UniqueCombatEngine.sharedDamageKeyword(for: damageKeyword, triggers: profile.triggers) {
            percent += profile.damageDealtPercents[sharedKeyword, default: 0]
        }
        percent = max(0, percent)
        let percentBonus = CombatRounding.scaled(max(0, state.remaining), multiplier: percent)
        state.itemBonus = SaturatedArithmetic.saturatingAdd(state.itemBonus, percentBonus)
        state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, percentBonus)
    }

    private static func applyDodgeEmpoweredBonuses(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.options.isAttackHit,
              let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID),
              let runtime = context.roster.runtime(for: source.combatant)
        else { return }
        if runtime.talents.pending.doubleDamageAfterDodge {
            state.remaining = SaturatedArithmetic.saturatingMul(state.remaining, 2)
            context.roster.mutateRuntime(for: source.combatant) { $0.talents.pending.doubleDamageAfterDodge = false }
        }
        if runtime.talents.pending.doubleNextAttackAfterDeathsDoor {
            state.remaining = SaturatedArithmetic.saturatingMul(state.remaining, 2)
            context.roster.mutateRuntime(for: source.combatant) { $0.talents.pending.doubleNextAttackAfterDeathsDoor = false }
        }
        let preparedDamage = SaturatedArithmetic.saturatingAdd(
            runtime.talents.pending.cardDamageBonus,
            runtime.talents.pending.feintStrikeDamageBonus,
        )
        if preparedDamage > 0 {
            state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, preparedDamage)
            context.roster.mutateRuntime(for: source.combatant) {
                $0.talents.pending.cardDamageBonus = 0
                $0.talents.pending.feintStrikeDamageBonus = 0
            }
        }
        if runtime.talents.pending.cardDamagePercent > 0 {
            state.remaining = CombatRounding.scaled(
                state.remaining,
                multiplier: 1 + runtime.talents.pending.cardDamagePercent,
            )
            context.roster.mutateRuntime(for: source.combatant) { $0.talents.pending.cardDamagePercent = 0 }
        }
        applyOvercharge(to: &state, source: source.combatant, in: &context)
        if runtime.talents.pending.damageAfterDodge > 0 {
            state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, runtime.talents.pending.damageAfterDodge)
            context.roster.mutateRuntime(for: source.combatant) { $0.talents.pending.damageAfterDodge = 0 }
        }
        if runtime.talents.timed.damage.amount > 0, context.turnCount < runtime.talents.timed.damage.expiresAtTurn {
            state.remaining = CombatRounding.scaled(
                state.remaining,
                multiplier: 1 + runtime.talents.timed.damage.amount,
            )
        }
    }

    private static func applyStunnedAndTalentMultipliers(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        if let sourceActorID = state.sourceActorID,
           state.targetStatus.isStunned {
            let profile = context.modifiers(for: sourceActorID)
            let multiplier = profile.triggers.stunnedDamageMultiplier
            if multiplier > 1 {
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: multiplier)
            }
        }
        if state.options.applyItemBonus {
            let talentMultiplier = CombatTriggerEngine.damageMultiplier(for: state, in: context)
            if talentMultiplier != 1 {
                state.remaining = CombatRounding.scaled(state.remaining, multiplier: talentMultiplier)
                appendAfflictedAuraLogEvents(to: &state, in: &context)
            }
        }
        applyHallowbreak(to: &state, in: context)
        applyTalentStatusMultipliers(to: &state, in: &context)
        applyCompanionStatusMultipliers(to: &state, in: &context)
        applyTalentBlockConsumption(to: &state, in: &context)
    }

    private static func applyTalentBlockConsumption(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard let keyword = state.damageKeyword,
              let sourceActorID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceActorID),
              state.combatant.role == .enemy
        else { return }
        let triggers = context.modifiers(for: sourceActorID).triggers
        if keyword == .stun, state.options.isAttackHit, triggers.stolenThunder {
            let block = DefensePoolEngine.blockPoints(in: context.roster.activeEffects(for: source.combatant))
            if block > 0, context.claimActionGuard(.stolenThunder, actorID: source.id) {
                DefensePoolEngine.set(0, on: source.combatant, in: &context)
                state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, block)
            }
        }
        guard keyword == .physical, state.options.isAttackHit, !state.options.isRetaliation else { return }
        var stored = 0
        if CombatTriggerEngine.hasLivingPartyTrigger(\.storedImpact, in: context) {
            for owner in [BattleParticipant.hero, .companion] {
                let member = context.roster[owner]
                if let val = context.storedBlockedDamageByActorID.removeValue(forKey: member.id) {
                    stored = SaturatedArithmetic.saturatingAdd(stored, val)
                }
            }
            if let extra = context.storedBlockedDamageByActorID.removeValue(forKey: source.id) {
                stored = SaturatedArithmetic.saturatingAdd(stored, extra)
            }
        } else if triggers.storedImpact {
            stored = context.storedBlockedDamageByActorID.removeValue(forKey: source.id) ?? 0
        }
        if stored > 0 {
            state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, stored)
        }
    }

    private static func appendAfflictedAuraLogEvents(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard let source = state.partySource(in: context) else { return }
        let target = state.combatant
        let names = CombatTriggerEngine.partyAfflictedDamageAuras(
            targetIsPoisoned: state.targetStatus.isPoisoned,
            targetIsBurning: state.targetStatus.isBurning,
            in: context,
        ).abilityNames
        for name in names {
            state.damageEvents.append(context.nextEvent(
                kind: .ability,
                actorName: source.name,
                abilityName: name,
                target: target,
                amount: 0,
                keyword: state.damageKeyword ?? .physical,
            ))
        }
    }

    private static func applyOneShotEmpowers(
        to state: inout DamageResolutionState,
    ) {
        state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, state.pendingAttackBonus)
        if state.damageKeyword == .holy {
            state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, state.pendingHolyBonus)
        } else {
            state.additionalHolyDamage = SaturatedArithmetic.saturatingAdd(state.additionalHolyDamage, state.pendingHolyBonus)
        }
    }

    private static func applyPartyDamageBonus(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.amount > 0 else { return }
        let bonus = context.resolution.consumePartyDamage(from: state.provenance)
        guard bonus > 0 else { return }
        state.remaining = SaturatedArithmetic.saturatingAdd(state.remaining, bonus)
    }

    static func reserveAttackEmpowers(to state: inout DamageResolutionState, in context: inout BattleState) {
        guard state.options.isAttackHit, let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID) else { return }
        context.roster.mutateRuntime(for: source.combatant) { runtime in
            let bonuses = runtime.talents.pending.reserveAttackBonuses()
            state.pendingAttackBonus = bonuses.damage + runtime.talents.battle.damageBonus
            state.pendingHolyBonus = bonuses.holy
        }
    }

    private static func applyOutgoingReductions(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard let sourceID = state.sourceActorID,
              let source = context.roster.combatant(for: sourceID)?.combatant else { return }
        let sourceIsFrozen = context.roster.hasControlStatus(for: source, keyword: .freeze)
        let sourceIsPoisoned = context.roster.hasAffliction(.poison, on: source)
        let sourceIsBleeding = context.roster.hasAffliction(.bleed, on: source)
        let sourceIsBurning = context.roster.hasAffliction(.burn, on: source)
        let sourceBleedStacks = context.roster.activeEffects(for: source).count(where: { $0.effect.isBleed })
        var reductionFlat = 0
        var reductionMultiplier = 1.0
        for opponent in BattleActionContext(actor: source, in: context).opponents(in: context)
            where context.roster.health(for: opponent) > 0 {
            let t = context.modifiers(for: opponent.id).triggers
            if sourceIsFrozen {
                reductionFlat += t.frozenEnemyDamageReductionFlat
            }
            if sourceIsBleeding {
                reductionFlat += t.bleedingEnemyDamageReductionFlat
                reductionMultiplier *= t.bleedingEnemyOutgoingDamageMultiplier
            }
            if sourceIsBurning {
                reductionFlat += t.burningEnemyDamageReductionFlat
            }
            if sourceIsPoisoned {
                reductionMultiplier *= (1 - min(1, t.poisonedEnemyAccuracyPenaltyPercent))
            }
            if sourceIsBleeding, t.enemyBleedStacksDamageReductionStacks > 0,
               sourceBleedStacks >= t.enemyBleedStacksDamageReductionStacks {
                reductionMultiplier *= (1 - min(1, t.enemyBleedStacksDamageReductionPercent))
            }
        }
        for active in context.roster.activeEffects(for: source) {
            switch active.effect {
            case let .damageReductionPercent(percent, _):
                reductionMultiplier *= (1 - min(1, percent))
            case let .damageReductionFlat(amount, _):
                reductionFlat += amount
            default:
                continue
            }
        }
        state.remaining = max(0, CombatRounding.scaled(state.remaining, multiplier: reductionMultiplier) - reductionFlat)
    }

    static func applyFightPacing(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.remaining > 0 else { return }
        state.remaining = context.paced(state.remaining, sourceActorID: state.sourceActorID)
        state.dealt = state.remaining
    }

    static func outgoingDamageBonus(
        for sourceActorID: String,
        keyword: Keyword,
        in context: BattleState,
    ) -> Int {
        let profile = context.modifiers(for: sourceActorID)
        var bonus = profile.damageDealtBonus(for: keyword)
        let sharedKeyword = UniqueCombatEngine.sharedDamageKeyword(for: keyword, triggers: profile.triggers)
        if let sharedKeyword {
            bonus += profile.damageDealtBonus(for: sharedKeyword)
        }
        if sourceActorID == context.roster.companion.id {
            bonus += context.heroModifiers.companionDamageDealtBonus + profile.companionDamageDealtBonus
            if keyword == .physical || sharedKeyword == .physical {
                bonus += context.heroModifiers.companionPhysicalDamageDealtBonus + profile.companionPhysicalDamageDealtBonus
            }
            if keyword == .bleed || sharedKeyword == .bleed {
                bonus += context.heroModifiers.companionBleedDamageDealtBonus
            }
        }
        if let source = context.roster.combatant(for: sourceActorID) {
            bonus += context.roster.runtime(for: source.combatant)?.talents.battle.keywordDamageRamp[keyword, default: 0] ?? 0
            if let sharedKeyword {
                bonus += context.roster.runtime(for: source.combatant)?.talents.battle.keywordDamageRamp[sharedKeyword, default: 0] ?? 0
            }
        }
        return bonus
    }

    static func applyCriticalMultiply(
        to state: inout DamageResolutionState,
        in context: inout BattleState,
    ) {
        guard state.isCritical, state.remaining > 0 else {
            return
        }
        let critMultiplier = criticalMultiplier(for: state.sourceActorID, in: context)
        let bonus = state.sourceActorID.map { context.modifiers(for: $0).criticalDamageBonus } ?? 0
        let percent = state.sourceActorID.map { context.modifiers(for: $0).criticalDamagePercent } ?? 0
        let criticalDamage = SaturatedArithmetic.saturatingAdd(
            CombatRounding.scaled(state.remaining, multiplier: critMultiplier), bonus,
        )
        state.remaining = CombatRounding.scaled(criticalDamage, multiplier: 1 + percent)
        if state.damageKeyword == .burn, state.options.isAttackHit, let sourceActorID = state.sourceActorID {
            state.remaining = SaturatedArithmetic.saturatingAdd(
                state.remaining, context.modifiers(for: sourceActorID).triggers.burnCriticalDamageBonus,
            )
        }
        if state.damageKeyword == .poison, state.options.isAttackHit, let sourceActorID = state.sourceActorID {
            state.remaining = SaturatedArithmetic.saturatingAdd(
                state.remaining, context.modifiers(for: sourceActorID).triggers.poisonCriticalDamageBonus,
            )
        }
        state.dealt = state.remaining
    }

    static func criticalMultiplier(for sourceActorID: String?, in context: BattleState) -> Double {
        var multiplier = 2.0
        if let sourceActorID,
           let source = context.roster.combatant(for: sourceActorID) {
            multiplier += context.roster.runtime(for: source.combatant)?.talents.battle.criticalMultiplierBonus ?? 0
        }
        return multiplier
    }
}
